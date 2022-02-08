% dj.Schema - manages information about database tables and their dependencies
%
% A TableAccessor object is created as a property of a schema during the
% schema's creation. This property is named schema.v for
% 'virtual class generator.' The TableAccessor v itself has properties that
% refer to the tables of the schema. For example, one can access the
% Session table using schema.v.Session with no need for any Session class
% to exist in Matlab. Tab completion of table names is possible because the
% table names are added as dynamic properties of TableAccessor.
%
%Complete documentation is available at 
% <a href=https://github.com/datajoint/datajoint-matlab/wiki>Datajoint wiki</a>

classdef Schema < handle
    
    properties(SetAccess = private)
        package    % the package (directory starting with a +) that stores schema classes, 
                   %    must be on path
        dbname     % database (schema) name
        prefix=''  % optional table prefix, allowing multiple schemas per database -- remove 
                   %    this feature if not used
        conn       % handle to the dj.Connection object
        loaded = false
        tableNames   % tables indexed by classNames
        headers    % dj.internal.Header objects indexed by table names
        v          % virtual class generator
        external
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
        allowedTiers = {'lookup' 'manual' 'imported' 'computed' 'job', 'hidden'}
        tierPrefixes = {'#', '', '_', '__', '~', '$'}
        tierClasses = {'dj.Lookup' 'dj.Manual' 'dj.Imported' 'dj.Computed' 'dj.Jobs', 'dj.Hidden'}
        baseRegexp = '[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*'
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
            self.headers    = containers.Map('KeyType','char','ValueType','any');
            self.tableNames = containers.Map('KeyType','char','ValueType','char');
            self.v = dj.internal.TableAccessor(self);
            self.external = dj.internal.ExternalMapping(self);
            conn.register(self);
        end
        
        
        function names = get.classNames(self)
            names =  self.tableNames.keys;
        end
        
        
        function makeClass(self, className, tableTierChoice)
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
            tierClassMap = struct(...
                'c','dj.Computed',...
                'l','dj.Lookup',...
                'm','dj.Manual',...
                'i','dj.Imported',...
                'p','dj.Part');
            if ismember([self.package '.' className], self.classNames)
                existingTable = dj.internal.Table([self.package '.' className]);
                fprintf('Table %s already exists, Creating matching class\n', ...
                    [self.package '.' className])
                isAuto = ismember(existingTable.info.tier, {'computed','imported'});
                tierClass = tierClassMap.(existingTable.info.tier(1));                
            else
                existingTable = [];
                if nargin < 3
                    tableTierChoice = dj.internal.ask(...
                        ['\nChoose table tier:\n  L=lookup\n  M=manual\n  I=imported\n  ' ...
                        'C=computed\n  P=part\n'],...
                        {'L','M','I','C','P'});
                end
                tierClass = tierClassMap.(lower(tableTierChoice));
                isAuto = ismember(tierClass, {'dj.Imported', 'dj.Computed'});
            end

            f = fopen(filename,'wt');
            assert(-1 ~= f, 'Could not open %s', filename)

            % table declaration
            if numel(existingTable)
                fprintf(f, '%s', existingTable.describe);
            else
                fprintf(f, '%%{\n');
                fprintf(f, '# my newest table\n');
                fprintf(f, '# add primary key here\n');
                fprintf(f, '-----\n');
                fprintf(f, '# add additional attributes\n');
                fprintf(f, '%%}');
            end
            
            % class definition
            fprintf(f, '\n\nclassdef %s < %s', className, tierClass);
                        
            % metod makeTuples
            if strcmp(tierClass, 'dj.Part')
                fprintf(f, '\n\n\tproperties(SetAccess=protected)');
                fprintf(f, '\n\t\tmaster= %s.<<MasterClass>>', self.package);
                fprintf(f, '\n\tend\n');
            end
            
            if isAuto
                fprintf(f, '\n\n\tmethods(Access=protected)');
                fprintf(f, '\n\n\t\tfunction makeTuples(self, key)\n');
                fprintf(f, '\t\t%%!!! compute missing fields for key here\n');
                fprintf(f, '\t\t\t self.insert(key)\n');
                fprintf(f, '\t\tend\n');
                fprintf(f, '\tend\n');
            end
            fprintf(f, '\nend');
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
        
        function reload(self, force)
            if ~self.loaded || (nargin<2 || force)
                % do not reload unless forced. Default is forced.
                self.loaded = true;
                self.conn.clearDependencies(self)
                self.headers.remove(self.headers.keys);
                self.tableNames.remove(self.tableNames.keys);
                
                % reload schema information into memory: table names and field named.
                if strcmpi(dj.config('loglevel'), 'DEBUG')
                    fprintf('loading table definitions from %s... ', self.dbname), tic
                end
                tableInfo = self.conn.query(sprintf(...
                    'SHOW TABLE STATUS FROM `%s` WHERE name REGEXP "{S}"', ...
                    self.dbname),self.tableRegexp,'bigint_to_double');
                tableInfo = dj.struct.rename(tableInfo,'Name','name','Comment','comment');
                
                % determine table tier (see dj.internal.Table)
                % regular expressions to determine table tier
                re = cellfun(@(x) sprintf('^%s%s[a-z][a-z0-9_]*$',self.prefix,x), ...
                    dj.Schema.tierPrefixes, 'UniformOutput', false);
                
                if strcmpi(dj.config('loglevel'), 'DEBUG')
                    fprintf('%.3g s\nloading field information... ', toc), tic
                end
                for info = dj.struct.fromFields(tableInfo)'
                    tierIdx = ~cellfun(@isempty, regexp(info.name, re, 'once'));
                    assert(sum(tierIdx)==1)
                    info.tier = dj.Schema.allowedTiers{tierIdx};
                    self.tableNames(sprintf('%s.%s',self.package,dj.internal.toCamelCase(...
                        info.name(length(self.prefix)+1:end)))) = info.name;
                    self.headers(info.name) = dj.internal.Header.initFromDatabase(self,info);
                end
                
                if strcmpi(dj.config('loglevel'), 'DEBUG')
                    fprintf('%.3g s\nloading dependencies... ', toc), tic
                end
                self.conn.loadDependencies(self)
                if strcmpi(dj.config('loglevel'), 'DEBUG')
                    fprintf('%.3g s\n',toc)
                end
            end
        end
        
        
        function disp(self)
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
                        dj.internal.toCamelCase(table.info.name),...
                        table.info.tier, table.info.comment)
                end
                fprintf('\n<a href="matlab:erd(%s.getSchema)">%s</a>\n', ...
                    self(i).package, 'Show entity relationship diagram')
            end
        end
        
        
        function erd(self)
            draw(dj.ERD(self))
        end
        
        function dropQuick(self)
            % drop the database and all its tables with no prompt -- use with caution             
            self.conn.query(sprintf('DROP DATABASE `%s`', self.dbname))
            disp done
        end
    end
end

