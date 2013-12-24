% dj.Schema - manages information about database tables and their dependencies
% Complete documentation is available at <a href=http://code.google.com/p/datajoint/wiki/TableOfContents>Datajoint wiki</a>
% See also dj.Table, dj.BaseRelvar, dj.GeneralRelvar

classdef Schema < handle
    
    properties(SetAccess = private)
        package    % the package (directory starting with a +) that stores schema classes, must be on path
        dbname     % database (schema) name
        prefix=''  % optional table prefix, allowing multiple schemas per database
        conn       % handle to the dj.Connection object
        loaded = false
        tableNames = containers.Map('KeyType','char','ValueType','char')  % tables indexed by classNames
        headers     = containers.Map('KeyType','char','ValueType','any')   % dj.Header objects indexed by table names
    end
    
    
    properties(Access=private)
        tableRegexp   % regular expression for legal table names
    end
    
    properties(Dependent)
        classNames
    end
    
    
    properties(Constant)
        % Table naming convention
        %   lookup:   tableName starts with a '#'
        %   manual:   tableName starts with a letter (no prefix)
        %   imported: tableName with a '_'
        %   computed: tableName with '__'
        allowedTiers = {'lookup' 'manual' 'imported' 'computed' 'job'}
        tierPrefixes = {'#', '', '_', '__', '~'}
    end
    
    
    properties(SetAccess=private)
        dependencies  % sparse adjacency matrix with 1=parent/child and 2=non-primary key reference
    end
    
    methods
        function self = Schema(conn, package, dbname)
            assert(isa(conn, 'dj.Connection'), ...
                'dj.Schema''s first input must be a dj.Connection')
            self.conn = conn;
            self.package = package;
            ix = find(dbname == '/');
            self.dbname = dbname;
            if ix
                % support multiple DataJoint schemas per database by prefixing tables names
                self.dbname = dbname(1:ix-1);
                self.prefix = [dbname(ix+1:end) '/'];
            end
            self.tableRegexp = ['^', self.prefix '(_|__|#|~)?[a-z][a-z0-9_]*$'];
            self.conn.addPackage(dbname, package)
        end
        
        
        function names = get.classNames(self)
            names =  self.tableNames.keys;
        end
        
        
        function makeClass(self, className)
            % create a base relvar class for the new className in schema directory.
            %
            % Example:
            %    schemaObject.makeClass('RegressionModel')
            useGUI = usejava('desktop') || usejava('awt') || usejava('swing');
            className = regexp(className,'^[A-Z][A-Za-z0-9]*$','match','once');
            assert(~isempty(className), 'invalid class name')
            
            % get the path to the schema package
            filename = fileparts(which(sprintf('%s.getSchema', self.package)));
            assert(~isempty(filename), 'could not find +%s/getSchema.m', self.package);
            
            % if the file already exists, let the user edit it and exit
            filename = fullfile(filename, [className '.m']);
            if exist(filename,'file')
                fprintf('%s already exists\n', filename)
                if useGUI
                    edit(filename)
                end
                return
            end
            
            % if the table exists, create the file that matches its definition
             if ismember([self.package '.' className], self.classNames)
                 existingTable = dj.Table([self.package '.' className]);
                 fprintf('Table %s already exists, Creating matching class\n', ...
                     [self.package '.' className])
                 isAuto = ismember(existingTable.info.tier, {'computed','imported'});
             else
                 existingTable = [];
                 choice = dj.ask(...
                     '\nChoose table tier:\n  L=lookup\n  M=manual\n  I=imported\n  C=computed\n',...
                     {'L','M','I','C'});
                tier = struct('c','computed','l','lookup','m','manual','i','imported');
                tier = tier.(choice);
                isAuto = ismember(tier, {'computed','imported'});
            end
            
            % let the user decide if the table is a subtable, which means
            % that it can only be populated together with its parent.
            isSubtable = isAuto && strcmp('yes', dj.ask('Is this a subtable?'));
            
            f = fopen(filename,'wt');
            assert(-1 ~= f, 'Could not open %s', filename)
            
            % table declaration
            if numel(existingTable)
                fprintf(f, '%s', existingTable.re);
                tab = dj.Table([self.package '.' className]);
                parents = tab.parents;
            else
                fprintf(f, '%%{\n');
                fprintf(f, '%s.%s (%s) # my newest table\n', self.package, className, tier);
                fprintf(f, '# add primary key here\n');
                fprintf(f, '-----\n');
                fprintf(f, '# add additional attributes\n');
                fprintf(f, '%%}');
                parents = [];
            end
            % class definition
            fprintf(f, '\n\nclassdef %s < dj.Relvar', className);
            if isAuto && ~isSubtable
                fprintf(f, ' & dj.AutoPopulate');
            end
            
            % properties
            if isAuto && ~isSubtable
                fprintf(f, '\n\n\tproperties\n');
                fprintf(f, '\t\tpopRel');
                for i = 1:length(parents)
                    if i>1
                        fprintf(f, '*');
                    else
                        fprintf(f, ' = ');
                    end
                    fprintf(f, '%s', parents{i});
                end
                fprintf(f, '  %% !!! update the populate relation\n');
            end
            fprintf(f, '\tend\n');
            
            % metod makeTuples
            if isAuto
                fprintf(f, '\n\tmethods');
                if ~isSubtable
                    fprintf(f, '(Access=protected)');
                end
                fprintf(f, '\n\n\t\tfunction makeTuples(self, key)\n');
                fprintf(f, '\t\t%%!!! compute missing fields for key here\n');
                fprintf(f, '\t\t\tself.insert(key)\n');
                fprintf(f, '\t\tend\n');
                fprintf(f, '\tend\n');
            end
            fprintf(f, 'end\n');
            fclose(f);
            if useGUI
                edit(filename)
            else
                fprintf('Class template written to %s\n', filename)
            end
        end
        
        function headers = get.headers(self)
            self.reload(false)
            headers = self.headers;
        end
        
        function tableNames = get.tableNames(self)
            self.reload(false)
            tableNames = self.tableNames;
        end
        
%         function erd(self, subset)
%             % ERD -- plot the Entity Relationship Diagram of the entire schema
%             %
%             % INPUTS:
%             %    subset -- a string array of classNames to include in the diagram
%             
%             % copy relevant information
%             C = self.dependencies;
%             levels = -self.tableLevels;
%             names = self.classNames;
%             tiers = {self.tables.tier};
%             tiers = [tiers repmat({'external'},1,length(names)-length(tiers))];
%             
%             if nargin<2
%                 % by default show all but the job tables
%                 subset = self.classNames(~strcmp(tiers,'job'));
%             else
%                 % limit the diagram to the specified subset of tables
%                 ix = find(~ismember(subset,self.classNames));
%                 if ~isempty(ix)
%                     dj.assert(false,'Unknown table %s', subset{ix(1)})
%                 end
%             end
%             subset = cellfun(@(x) find(strcmp(x,self.classNames)), subset);
%             levels = levels(subset);
%             C = C(subset,subset);  % connectivity matrix
%             names = names(subset);
%             tiers = tiers(subset);
%             
%             if sum(C)==0
%                 disp 'No dependencies found. Nothing to plot'
%                 return
%             end
%             
%             yi = levels;
%             xi = zeros(size(yi));
%             
%             % optimize graph appearance by minimizing disctances.^2 to connected nodes
%             % while maximizing distances to nodes on the same level.
%             j1 = cell(1,length(xi));
%             j2 = cell(1,length(xi));
%             for i=1:length(xi)
%                 j1{i} = setdiff(find(yi==yi(i)),i);
%                 j2{i} = [find(C(i,:)) find(C(:,i)')];
%             end
%             niter=5e4;
%             T0=5; % initial temperature
%             cr=6/niter; % cooling rate
%             L = inf(size(xi));
%             for iter=1:niter
%                 i = ceil(rand*length(xi));  % pick a random node
%                 
%                 % Compute the cost function Lnew of the increasing xi(i) by dx
%                 dx = 5*randn*exp(-cr*iter/2);  % steps don't cools as fast as the annealing schedule
%                 xx=xi(i)+dx;
%                 Lnew = abs(xx)/10 + sum(abs(xx-xi(j2{i}))); % punish for remoteness from center and from connected nodes
%                 if ~isempty(j1{i})
%                     Lnew= Lnew+sum(1./(0.01+(xx-xi(j1{i})).^2));  % punish for propximity to same-level nodes
%                 end
%                 
%                 if L(i) > Lnew + T0*randn*exp(-cr*iter) % simulated annealing
%                     xi(i)=xi(i)+dx;
%                     L(i) = Lnew;
%                 end
%             end
%             yi = yi+cos(xi*pi+yi*pi)*0.2;  % stagger y positions at each level
%             
%             
%             % plot nodes
%             plot(xi, yi, 'ko', 'MarkerSize', 10);
%             hold on;
%             % plot edges
%             for i=1:size(C,1)
%                 for j=1:size(C,2)
%                     switch C(i,j)
%                         case 1
%                             connectNodes(xi([i j]), yi([i j]), 'k-')
%                         case 2
%                             connectNodes(xi([i j]), yi([i j]), 'k--')
%                     end
%                     hold on
%                 end
%             end
%             
%             % annotate nodes
%             fontColor = struct(...
%                 'external', [0.0 0.0 0.0], ...
%                 'manual',   [0.0 0.6 0.0], ...
%                 'lookup',   [0.3 0.4 0.3], ...
%                 'imported', [0.0 0.0 1.0], ...
%                 'computed', [0.5 0.0 0.0], ...
%                 'job',      [1 1 1]);
%             
%             for i=1:length(levels)
%                 name = names{i};
%                 isExternal = ~strcmp(strtok(name,'.'), self.package);
%                 if isExternal
%                     edgeColor = [0.3 0.3 0.3];
%                     fontSize = 9;
%                     name = self.conn.getPackage(name);
%                 else
%                     if exist(name,'class')
%                         rel = feval(name);
%                         dj.assert(isa(rel, 'dj.Relvar'))
%                         if rel.isSubtable
%                             name = [name '*'];  %#ok:AGROW
%                         end
%                     end
%                     name = name(length(self.package)+2:end);  %remove package name
%                     edgeColor = 'none';
%                     fontSize = 11;
%                 end
%                 text(xi(i), yi(i), [name '  '], ...
%                     'HorizontalAlignment', 'right', 'interpreter', 'none', ...
%                     'Color', fontColor.(tiers{i}), 'FontSize', fontSize, 'edgeColor', edgeColor);
%                 hold on;
%             end
%             
%             xlim([min(xi)-0.5 max(xi)+0.5]);
%             ylim([min(yi)-0.5 max(yi)+0.5]);
%             hold off
%             axis off
%             title(sprintf('%s (%s)', self.package, self.dbname), ...
%                 'Interpreter', 'none', 'fontsize', 14,'FontWeight','bold', 'FontName', 'Ariel')
%             
%             function connectNodes(x, y, lineStyle)
%                 dj.assert(length(x)==2 && length(y)==2)
%                 plot(x, y, 'k.')
%                 t = 0:0.05:1;
%                 x = x(1) + (x(2)-x(1)).*(1-cos(t*pi))/2;
%                 y = y(1) + (y(2)-y(1))*t;
%                 plot(x, y, lineStyle)
%             end
%         end
%         
%         function backup(self, backupDir, tiers, restrictor)
%             % dj.Schema/backup - saves tables into .mat files
%             % SYNTAX:
%             %    s.backup(folder)    -- save all lookup and manual tables
%             %    s.backup(folder, {'manual'})    -- save all manual tables
%             %    s.backup(folder, {'manual','imported'})
%             %    s.backup(folder, [], restrictor)  -- backup only tuples that match restrictor
%             %
%             % Each table must be small enough to be loaded into memory.
%             % By default, only lookup and manual tables are saved.
%             %
%             % restrictor may contain a cell array of conditions. However,
%             % string conditions can cause errors for some tables.
%             % The best practice is to use a structure or a relvar as a restrictor, e.g.
%             % backup(ephys.getSchema, '/backup', [], ephys.Session('session_date > "2012-07-10"'))
%             
%             if nargin<3 || isempty(tiers)
%                 tiers = {'lookup','manual'};
%             end
%             if nargin<4
%                 restrictor = {};
%             end
%             dj.assert(all(ismember(tiers, dj.Schema.allowedTiers)))
%             backupDir = fullfile(backupDir, self.dbname);
%             if ~exist(backupDir, 'dir')
%                 dj.assert(mkdir(backupDir), 'Could not create directory %s', backupDir)
%             end
%             backupDir = fullfile(backupDir, datestr(now,'yyyy-mm-dd'));
%             if ~exist(backupDir,'dir')
%                 dj.assert(mkdir(backupDir), 'Could not create directory %s', backupDir)
%             end
%             ix = find(ismember({self.tables.tier}, tiers));
%             % save in hiearchical order
%             [~,order] = sort(self.tableLevels(ix));
%             ix = ix(order);
%             for iTable = ix(:)'
%                 className = self.classNames{iTable};
%                 rel = init(dj.BaseRelvar, dj.Table(className)) & restrictor;
%                 contents = rel.fetch('*'); %#ok<NASGU>
%                 filename = fullfile(backupDir, ...
%                     regexprep(self.classNames{iTable}, '^.*\.', ''));
%                 fprintf('Saving %s to %s ...', self.classNames{iTable}, filename)
%                 save(filename, 'contents')
%                 fprintf 'done\n'
%             end
%         end
%         
%         function restore(self, backupDir)
%             % restore(schema, backupDir)
%             % insert all missing tuples from tables saved in <ClassName>.MAT files in backupDir
%             d = dir(fullfile(backupDir,'*.mat'));
%             
%             % instantiate all classes
%             classes = cell(length(d),1);
%             objects = cell(length(d),1);
%             for i=1:length(d)
%                 try
%                     classes{i} = [self.package '.' regexprep(d(i).name, '\.mat$', '')];
%                     objects{i} = eval(classes{i});
%                     objects{i}.header;  % this will trigger the creation of a table if missing.
%                 catch err
%                     dj.assert(false,['!invalidClass:' err.message])
%                     continue
%                 end
%             end
%             ix = ~cellfun(@isempty, classes);
%             classes = classes(ix);
%             objects = objects(ix);
%             d = d(ix);
%             
%             % sort objects by hiararchical level
%             levels = cellfun(@(x) self.tableLevels(strcmp(x, self.classNames)), classes);
%             [~, ix] = sort(levels);
%             classes = classes(ix);
%             objects = objects(ix);
%             d = d(ix);
%             
%             % insert tuples
%             for i=1:length(classes)
%                 s = load(fullfile(backupDir, d(i).name));
%                 try
%                     fprintf('inserting %d tuples into %s\n', length(s.contents), classes{i})
%                     objects{i}.insert(s.contents, 'INSERT IGNORE');
%                 catch err
%                     dj.assert(false,['!TableDeclarationMismatch:' err.message])
%                 end
%             end
%         end
        
        function reload(self, force)
            force = nargin<2 || force;
            if self.loaded && ~force
                return
            end
            self.loaded = true;
            
            % reload schema information into memory: table names and field named.
            fprintf('loading table definitions from %s... ', self.dbname)
            tic
            tableInfo = self.conn.query(sprintf(...
                'SHOW TABLE STATUS FROM `%s` WHERE name REGEXP "{S}"', ...
                self.dbname),self.tableRegexp,'bigint_to_double');
            tableInfo = dj.struct.rename(tableInfo,'Name','name','Comment','comment');
            
            % determine table tier (see dj.Table)
            re = cellfun(@(x) sprintf('^%s%s[a-z][a-z0-9_]*$',self.prefix,x), ...
                dj.Schema.tierPrefixes, 'UniformOutput', false); % regular expressions to determine table tier
            
            fprintf('%.3g s\nloading field information... ', toc), tic
            for info = dj.struct.fromFields(tableInfo)'
                tierIdx = ~cellfun(@isempty, regexp(info.name, re, 'once'));
                assert(sum(tierIdx)==1)
                info.tier = dj.Schema.allowedTiers{tierIdx};
                self.tableNames(self.makeClassName(self.dbname, info.name)) = info.name;
                self.headers(info.name) = dj.Header.initFromDatabase(self,info);
            end
            fprintf('%.3g\n',toc)
        end
        
        
        function display(self)
            self.reload(false)
            for i=1:numel(self)
                fprintf('\nDataJoint schema %s, stored in MySQL database %s', ...
                    self(i).package, self(i).dbname)
                if ~isempty(self(i).prefix)
                    fprintf(' with table prefix %s\n\n', self(i).prefix)
                else
                    fprintf \n\n
                end
                fprintf('%-25s%-16s%s\n%s\n', ...
                    'Table name', 'Tier', 'Comment',repmat('#',1,80))
                schema = self(i);
                for key=schema.headers.keys
                    table = schema.headers(key{1});
                    fprintf('%20s %10s  %s\n', ...
                        dj.Schema.toCamelCase(table.info.name),...
                        table.info.tier, table.info.comment)
                end
                fprintf('\n<a href="matlab:erd(%s.getSchema)">%s</a>\n', ...
                    self(i).package, 'Show entity relationship diagram')
            end
        end
    end
    
    
    methods(Access = private)
        function str = makeClassName(self, db, tab)
            % produce class name from database and table.
            
            % support multiple schemas per database
            ix = find(tab=='/');
            if ix
                db = [db '/' tab(1:ix(1)-1)];
                tab = tab(ix(1)+1:end);
            end
            str = self.conn.getPackage(['$' db '.' dj.Schema.toCamelCase(tab)]);
        end
    end
    
    
    methods(Static)
        function str = toCamelCase(str)
            % converts underscore_compound_words to CamelCase
            %
            % Not always exactly inversible
            %
            % Examples:
            %   toCamelCase('one')            -->  'One'
            %   toCamelCase('one_two_three')  -->  'OneTwoThree'
            %   toCamelCase('#$one_two,three') --> 'OneTwoThree'
            %   toCamelCase('One_Two_Three')  --> !error! upper case only mixes with alphanumericals
            %   toCamelCase('5_two_three')    --> !error! cannot start with a digit
            
            assert(isempty(regexp(str, '\s', 'once')), 'white space is not allowed')
            assert(~ismember(str(1), '0':'9'), 'string cannot begin with a digit')
            assert(isempty(regexp(str, '[A-Z]', 'once')), ...
                'underscore_compound_words must not contain uppercase characters')
            str = regexprep(str, '(^|[_\W]+)([a-zA-Z])', '${upper($2)}');
        end
        
        
        
        function str = fromCamelCase(str)
            % converts CamelCase to underscore_compound_words.
            %
            % Examples:
            %   fromCamelCase('oneTwoThree')    --> 'one_two_three'
            %   fromCamelCase('OneTwoThree')    --> 'one_two_three'
            %   fromCamelCase('one two three')  --> !error! white space is not allowed
            %   fromCamelCase('ABC')            --> 'a_b_c'
            
            assert(isempty(regexp(str, '\s', 'once')), 'white space is not allowed')
            assert(~ismember(str(1), '0':'9'), 'string cannot begin with a digit')
            
            assert(~isempty(regexp(str, '^[a-zA-Z0-9]*$', 'once')), ...
                'fromCamelCase string can only contain alphanumeric characters');
            str = regexprep(str, '([A-Z])', '_${lower($1)}');
            str = str(1+(str(1)=='_'):end);  % remove leading underscore
        end
    end
end

