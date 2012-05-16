% manages information about database tables and their dependencies
% Complete documentation is available at <a href=http://code.google.com/p/datajoint/wiki/TableOfContents>Datajoint wiki</a>
% See also dj.Table, dj.BaseRelvar, dj.GeneralRelvar

classdef Schema < handle
    
    properties(SetAccess = private)
        package % the package (directory starting with a +) that stores schema classes, must be on path
        dbname  % database (schema) name
        conn    % handle to the dj.Connection object
        
        % table information loaded from the schema
        loaded = false
        classNames    % classes corresponding to self.tables plus all referenced tables from other schemas.
        tables        % full list of tables
        header        % full list of all table attributes
        tableLevels   % levels in dependency hiararchy
    end
    
    properties(Access=private)
        dependencies  % sparse adjacency matrix with 1=parent/child and 2=non-primary key reference
    end
    
    methods
        
        function self = Schema(conn, package, dbname)
            assert(isa(conn, 'dj.Connection'), ...
                'dj.Schema''s first input must be a dj.Connection')
            self.conn = conn;
            self.dbname = dbname;
            self.package = package;
            addPackage(self.conn, dbname, package)
        end
        
        
        function val = get.classNames(self)
            self.reload(false)
            val = self.classNames;
        end
        
        function val = get.tables(self)
            self.reload(false)
            val = self.tables;
        end
        
        function val = get.header(self)
            self.reload(false)
            val = self.header;
        end
        
        function val = get.dependencies(self)
            self.reload(false)
            val = self.dependencies;
        end
        
        function val = get.tableLevels(self)
            self.reload(false)
            val = self.tableLevels;
        end
        
        
        function makeClass(self, className)
            % create a base relvar class for the new className in schema directory.
            %
            % Example:
            %    makeClass(v2p.getSchema, 'RegressionModel')
            
            if nargin<2
                className = input('Enter class name >', 's');
            end
            className = regexp(className,'^[A-Z][A-Za-z0-9]*$','match','once');
            assert(~isempty(className), 'invalid class name')
            
            % get the path to the scema package
            filename = fileparts(which(sprintf('%s.getSchema', self.package)));
            assert(~isempty(filename), 'could not find +%s/getSchema.m', self.package);
            filename = fullfile(filename, [className '.m']);
            if exist(filename,'file')
                fprintf('%s already exists\n', filename)
                edit(filename)
                return
            end
            
            if ismember([self.package '.' className], self.classNames)
                % Check if the table already exists and create the class to
                % match the table definition
                existingTable = dj.Table([self.package '.' className]);
                fprintf('Table %s already exists, Creating matching class\n', ...
                    [self.package '.' className])
                isAuto = ismember(existingTable.info.tier, {'computed','imported'});
            else
                existingTable = [];
                choice = 'x';
                while length(choice)~=1 || ~ismember(choice,'lmic')
                    choice = lower(input('\nChoose table tier:\n    L=lookup\n    M=manual\n    I=imported\n    C=computed\n  > ', 's'));
                end
                tier = struct('c','computed','l','lookup','m','manual','i','imported');
                tier = tier.(choice);
                isAuto = ismember(tier, {'computed','imported'});
            end
            
            
            isSubtable = false;
            if isAuto
                choice = '';
                while ~ismember(choice, {'yes','no'})
                    choice = input('Is this a subtable? yes/no > ', 's');
                end
                isSubtable = strcmp('yes',choice);
            end
            
            
            f = fopen(filename,'wt');
            assert(-1 ~= f, 'Could not open %s', filename)
            
            % table declaration
            if numel(existingTable)
                fprintf(f, '%s', existingTable.re);
                parentIndices = self.getParents([self.package '.' className]);
                parentIndices(end) = [];  % remove this table
            else
                fprintf(f, '%%{\n');
                fprintf(f, '%s.%s (%s) # my newest table\n', self.package, className, tier);
                schemaList = struct2cell(self.conn.packageDict);
                parentSelection = {};
                for iSchema=1:length(schemaList)
                    schema = eval([schemaList{iSchema} '.getSchema']);
                    parentSelection = [parentSelection schema.classNames(~strncmp(schema.classNames,'$',1))]; %#ok<AGROW>
                end
                if ~isempty(parentSelection)
                    parentSelection = sort(parentSelection);
                    disp 'Selecting parent table(s)'
                    parentIndices = listdlg('ListString',parentSelection,'PromptString','Select parent table(s)');
                    if ~isempty(parentIndices)
                        fprintf(f, '-> %s\n', parentSelection{parentIndices});
                    end
                end
                fprintf(f, '\n-----\n\n');
                fprintf(f, '%%}');
            end
            % class definition
            fprintf(f, '\n\nclassdef %s < dj.Relvar', className);
            if isAuto && ~isSubtable
                fprintf(f, ' & dj.AutoPopulate');
            end
            
            % properties
            fprintf(f, '\n\n\tproperties(Constant)\n');
            fprintf(f, '\t\ttable = dj.Table(''%s.%s'')\n', self.package, className);
            if isAuto && ~isSubtable
                fprintf(f, '\t\tpopRel');
                for i = 1:length(parentIndices)
                    if i>1
                        fprintf(f, '*');
                    else
                        fprintf(f, ' = ');
                    end
                    fprintf(f, '%s', parentSelection{parentIndices(i)});
                end
                fprintf(f, '  %% !!! update the populate relation\n');
            end
            fprintf(f, '\tend\n');
            
            % constructor
            fprintf(f, '\n\tmethods\n');
            fprintf(f, '\t\tfunction self = %s(varargin)\n', className);
            fprintf(f, '\t\t\tself.restrict(varargin)\n');
            fprintf(f, '\t\tend\n');
            
            % metod makeTuples
            if isAuto
                if ~isSubtable
                    fprintf(f, '\tend\n');
                    fprintf(f, '\n\tmethods(Access=protected)\n');
                end
                fprintf(f, '\n\t\tfunction makeTuples(self, key)\n');
                fprintf(f, '\t\t%%!!! compute missing fields for key here\n');
                fprintf(f, '\t\t\tself.insert(key)\n');
                fprintf(f, '\t\tend\n');
            end
            fprintf(f, '\tend\n');
            fprintf(f, 'end\n');
            fclose(f);
            edit(filename)
        end
        
        
        function erd(self, subset)
            % ERD -- plot the Entity Relationship Diagram of the entire schema
            %
            % INPUTS:
            %    subset -- a string array of classNames to include in the diagram
            
            % copy relevant information
            C = self.dependencies;
            levels = -self.tableLevels;
            names = self.classNames;
            tiers = {self.tables.tier};
            tiers = [tiers repmat({'external'},1,length(names)-length(tiers))];
            
            if nargin>=2
                % limit the diagram to the specified subset of tables
                ix = find(~ismember(subset,self.classNames));
                if ~isempty(ix)
                    error('Unknown table %d', subset(ix(1)));
                end
                subset = cellfun(@(x) find(strcmp(x,self.classNames)), subset);
                levels = levels(subset);
                C = C(subset,subset);  % connectivity matrix
                names = self.classNames(subset);
                tiers = tiers(subset);
            end
            
            if sum(C)==0
                disp 'No dependencies found. Nothing to plot'
                return
            end
            
            yi = levels;
            xi = zeros(size(yi));
            
            % optimize graph appearance by minimizing disctances.^2 to connected nodes
            % while maximizing distances to nodes on the same level.
            fprintf 'optimizing layout...'
            j1 = cell(1,length(xi));
            j2 = cell(1,length(xi));
            for i=1:length(xi)
                j1{i} = setdiff(find(yi==yi(i)),i);
                j2{i} = [find(C(i,:)) find(C(:,i)')];
            end
            niter=5e4;
            T0=5; % initial temperature
            cr=6/niter; % cooling rate
            L = inf(size(xi));
            for iter=1:niter
                i = ceil(rand*length(xi));  % pick a random node
                
                % Compute the cost function Lnew of the increasing xi(i) by dx
                dx = 5*randn*exp(-cr*iter/2);  % steps don't cools as fast as the annealing schedule
                xx=xi(i)+dx;
                Lnew = abs(xx)/10 + sum(abs(xx-xi(j2{i}))); % punish for remoteness from center and from connected nodes
                if ~isempty(j1{i})
                    Lnew= Lnew+sum(1./(0.01+(xx-xi(j1{i})).^2));  % punish for propximity to same-level nodes
                end
                
                if L(i) > Lnew + T0*randn*exp(-cr*iter) % simulated annealing
                    xi(i)=xi(i)+dx;
                    L(i) = Lnew;
                end
            end
            yi = yi+cos(xi*pi+yi*pi)*0.2;  % stagger y positions at each level
            
            
            % plot nodes
            plot(xi, yi, 'ko', 'MarkerSize', 10);
            hold on;
            % plot edges
            for i=1:size(C,1)
                for j=1:size(C,2)
                    switch C(i,j)
                        case 1
                            connectNodes(xi([i j]), yi([i j]), 'k-')
                        case 2
                            connectNodes(xi([i j]), yi([i j]), 'k--')
                    end
                    hold on
                end
            end
            
            % annotate nodes
            fontColor = struct(...
                'external', [0.0 0.0 0.0], ...
                'manual',   [0.0 0.6 0.0], ...
                'lookup',   [0.3 0.4 0.3], ...
                'imported', [0.0 0.0 1.0], ...
                'computed', [0.5 0.0 0.0]);
            
            for i=1:length(levels)
                name = names{i};
                isExternal = ~strncmp(name, self.package, length(self.package));
                
                edgeColor = [0.3 0.3 0.3];
                fontSize = 9;
                if isExternal
                    name = getPackage(self.conn, name, false);
                else
                    try
                        if isSubtable(eval(name))
                            name = [name '*'];  %#ok:AGROW
                        end
                    catch %#ok
                    end
                    name = name(length(self.package)+2:end);  %remove package name
                    edgeColor = 'none';
                    fontSize = 11;
                end
                text(xi(i), yi(i), [name '  '], ...
                    'HorizontalAlignment', 'right', 'interpreter', 'none', ...
                    'Color', fontColor.(tiers{i}), 'FontSize', fontSize, 'edgeColor', edgeColor);
                hold on;
            end
            
            xlim([min(xi)-0.5 max(xi)+0.5]);
            ylim([min(yi)-0.5 max(yi)+0.5]);
            hold off
            axis off
            title(sprintf('%s (%s)', self.package, self.dbname), ...
                'Interpreter', 'none', 'fontsize', 14,'FontWeight','bold', 'FontName', 'Ariel')
            disp done
            
            
            function connectNodes(x, y, lineStyle)
                assert(length(x)==2 && length(y)==2)
                plot(x, y, 'k.')
                t = 0:0.05:1;
                x = x(1) + (x(2)-x(1)).*(1-cos(t*pi))/2;
                y = y(1) + (y(2)-y(1))*t;
                plot(x, y, lineStyle)
            end
        end
        
        
        function backup(self, backupDir, tiers)
            % dj.Schema/backup - saves tables into .mat files
            % SYNTAX:
            %    s.backup(folder)    -- save all lookup and manual tables
            %    s.backup(folder, {'manual'})    -- save all manual tables
            %    s.backup(folder, {'manual','imported'})
            % Each table must be small enough to be loaded into memory.
            % By default, only lookup and manual tables are saved.
            
            if nargin<3
                tiers = {'lookup','manual'};
            end
            assert(all(ismember(tiers, dj.utils.allowedTiers)))
            backupDir = fullfile(backupDir, self.dbname);
            if ~exist(backupDir, 'dir')
                assert(mkdir(backupDir), ...
                    'Could not create directory %s', backupDir)
            end
            backupDir = fullfile(backupDir, datestr(now,'yyyy-mm-dd'));
            if ~exist(backupDir,'dir')
                assert(mkdir(backupDir), ...
                    'Could not create directory %s', backupDir)
            end
            ix = find(ismember({self.tables.tier}, tiers));
            % save in hiearchical order
            [~,order] = sort(self.tableLevels(ix));
            ix = ix(order);
            for iTable = ix(:)'
                contents = self.conn.query(sprintf('SELECT * FROM `%s`.`%s`', ...
                    self.dbname, self.tables(iTable).name));
                contents = dj.struct.fromFields(contents);
                filename = fullfile(backupDir, ...
                    regexprep(self.classNames{iTable}, '^.*\.', ''));
                fprintf('Saving %s to %s ...', self.classNames{iTable}, filename)
                save(filename, 'contents')
                fprintf 'done\n'
            end
        end
        
        
        function reload(self, force)
            force = nargin<2 || force;
            if self.loaded && ~force
                return
            end
            self.loaded = true;
            
            % reload schema information into memory: table names and table
            % dependencies.
            % reload table information
            fprintf('loading table definitions from %s... ', self.dbname)
            tic
            self.tables = self.conn.query(sprintf([...
                'SELECT table_name AS name, table_comment AS comment ' ...
                'FROM information_schema.tables ' ...
                'WHERE table_schema="%s" AND table_name REGEXP "^(__|_|#)?[a-z][a-z0-9_]*$"'], ...
                self.dbname));
            
            % determine table tier (see dj.Table)
            re = cellfun(@(x) sprintf('^%s[a-z][a-z0-9_]*$',x), ...
                dj.utils.tierPrefixes, 'UniformOutput', false); % regular expressions to determine table tier
            tierIdx = cellfun(@(x) ...
                find(~cellfun(@isempty, regexp(x, re, 'once')),1,'first'), ...
                self.tables.name);
            self.tables.tier = dj.utils.allowedTiers(tierIdx)';
            
            self.tables.comment = cellfun(@(x) strtok(x,'$'), ...
                self.tables.comment, 'UniformOutput', false);  % strip MySQL's comment
            self.tables = dj.struct.fromFields(self.tables);
            self.classNames = cellfun(@(x) makeClassName(self.dbname, x), ...
                {self.tables.name}, 'UniformOutput', false);
            
            % read field information
            if ~isempty(self.tables)
                fprintf('%.3g s\nloading field information... ', toc), tic
                self.header = self.conn.query(sprintf([...
                    'SELECT table_name AS `table`, column_name as `name`,'...
                    '(column_key="PRI") AS `iskey`,column_type as `type`,'...
                    '(is_nullable="YES") AS isnullable, column_comment as `comment`,'...
                    'if(is_nullable="YES","NULL",ifnull(CAST(column_default AS CHAR),"<<<none>>>"))',...
                    ' AS `default` FROM information_schema.columns '...
                    'WHERE table_schema="%s"'],...
                    self.dbname));
                self.header.isnullable = logical(self.header.isnullable);
                self.header.iskey = logical(self.header.iskey);
                self.header.isNumeric = ~cellfun(@(x) isempty(regexp(char(x'), ...
                    '^((tiny|small|medium|big)?int|decimal|double|float)', 'once')), self.header.type);
                self.header.isString = ~cellfun(@(x) isempty(regexp(char(x'), ...
                    '^((var)?char|enum|date|time|timestamp)','once')), self.header.type);
                self.header.isBlob = ~cellfun(@(x) isempty(regexp(char(x'), ...
                    '^(tiny|medium|long)?blob', 'once')), self.header.type);
                % strip field lengths off integer types
                self.header.type = cellfun(@(x) regexprep(char(x'), ...
                    '((tiny|long|small|)int)\(\d+\)','$1'), self.header.type, 'UniformOutput', false);
                self.header.alias = repmat({''}, length(self.header.name),1);
                self.header = dj.struct.fromFields(self.header);
                self.header = self.header(ismember({self.header.table}, {self.tables.name}));
                validFields = [self.header.isNumeric] | [self.header.isString] | [self.header.isBlob];
                if ~all(validFields)
                    ix = find(~validFields, 1, 'first');
                    error('unsupported field type "%s" in %s.%s', ...
                        self.header(ix).type, self.header.table(ix), self.header.name(ix));
                end
                
                % reload table dependencies
                fprintf('%.3g s\nloading table dependencies... ', toc), tic
                foreignKeys = dj.struct.fromFields(self.conn.query(sprintf([...
                    'SELECT'...
                    '  table_schema AS from_schema,'...
                    '  table_name AS from_table,'...
                    '  referenced_table_schema AS to_schema,'...
                    '  referenced_table_name  AS to_table, '...
                    '  min((table_schema, table_name, column_name) in'...
                    '    (SELECT table_schema, table_name, column_name'...
                    '    FROM information_schema.columns WHERE column_key="PRI")) as hierarchical '...
                    'FROM information_schema.key_column_usage '...
                    'WHERE (table_schema="%s" AND referenced_table_schema is not null'...
                    '   OR referenced_table_schema="%s") '...
                    '  AND table_name REGEXP "^(__|_|#)?[a-z][a-z0-9_]*$"'...
                    '  AND referenced_table_name REGEXP "^(__|_|#)?[a-z][a-z0-9_]*$" '...
                    'GROUP BY table_schema, table_name, referenced_table_schema, referenced_table_name'],...
                    self.dbname, self.dbname)));
                
                % compile classNames for linked tables from outside the schema
                toClassNames = arrayfun(@(x) makeClassName(x.to_schema, x.to_table), foreignKeys, 'uni', false)';
                fromClassNames = arrayfun(@(x) makeClassName(x.from_schema, x.from_table), foreignKeys, 'uni', false)';
                self.classNames = [self.classNames, setdiff(unique([toClassNames fromClassNames]), self.classNames)];
                
                % create dependency matrix
                ixFrom = cellfun(@(x) find(strcmp(x, self.classNames)), fromClassNames);
                ixTo   = cellfun(@(x) find(strcmp(x, self.classNames)), toClassNames);
                nTables = length(self.classNames);
                
                self.dependencies = sparse(ixFrom, ixTo, 2-[foreignKeys.hierarchical], nTables, nTables);
                
                % determine tables' hierarchical level
                K = self.dependencies;
                ik = 1:nTables;
                levels = nan(size(ik));
                level = 0;
                while ~isempty(K)
                    orphans = sum(K,2)==0;
                    levels(ik(orphans)) = level;
                    level = level + 1;
                    ik = ik(~orphans);
                    K = K(~orphans,~orphans);
                end
                
                % lower level if possible
                for ii=1:3
                    for j=1:nTables
                        ix = find(self.dependencies(:,j));
                        if ~isempty(ix)
                            levels(j)=min(levels(ix)-1);
                        end
                    end
                end
                fprintf('%.3g s\n', toc)
                
                self.tableLevels = levels;
            end
            
            
            function str = makeClassName(db,tab)
                if strcmp(db,self.dbname)
                    str = self.package;
                else
                    str = ['$' db];
                end
                str = sprintf('%s.%s', str, dj.utils.camelCase(tab));
            end
        end
        
        
        function names = getParents(self, className, hierarchy, crossSchemas)
            % retrieve the class names of the parents of given table classes
            if nargin<3
                hierarchy = [1 2];
            end
            crossSchemas = nargin>=4 && crossSchemas;
            names = self.getRelatives(className, true, hierarchy, crossSchemas);
        end
        
        
        function names = getChildren(self, className, hierarchy, crossSchemas)
            % retrieve the class names of the parents of given table classes
            if nargin<3
                hierarchy = [1 2];
            end
            crossSchemas = nargin>=4 && crossSchemas;
            names = self.getRelatives(className, false, hierarchy, crossSchemas);
        end
        
        
        function names = getRelatives(self, className, up, hierarchy, crossSchemas)
            names = {};
            if ~isempty(className)
                if ischar(className)
                    if crossSchemas || className(1)~='$'
                        className = self.conn.getPackage(className);
                        pack = strtok(className,'.');
                        if ~strcmp(pack, self.package) && crossSchemas
                            % parents from other packages
                            otherSchema = eval([pack '.getSchema']);
                            names = [names ...
                                otherSchema.getRelatives(className, up, hierarchy, crossSchemas)];
                        else
                            ix = strcmp(self.classNames, className);
                            if any(ix)
                                if up
                                    names = self.classNames(ismember(self.dependencies(ix,:),hierarchy));
                                else
                                    names = self.classNames(ismember(self.dependencies(:,ix),hierarchy));
                                end
                            end
                        end
                    end
                elseif iscellstr(className)
                    for i=1:length(className)
                        newNames = self.getRelatives(className{i}, up, hierarchy, crossSchemas);
                        if up
                            names = [newNames names];    %#ok:AGROW
                        else
                            names = [names newNames];    %#ok:AGROW
                        end
                    end
                end
            end
        end
    end
end