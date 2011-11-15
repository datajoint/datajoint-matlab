% dj.Table provides the data definition interface to a single table in the
% database.
%
% Initialization:
%    table = dj.Table('package.ClassName')
%
% If the table does not exist, it is created based on the definition
% specified in the first percent-brace comment block in the file whose path
% is returned by which('package.ClassName'), which will normally contain the
% class definition of the derived class that works with this table.
%
% The file +package/ClassName.m need not exist if the table already exists
% in the database. Only if the table does not exist will dj.Table access
% the table definition file and create the table in the database.
%
% The syntax of the table definition can be found at
% http://code.google.com/p/datajoint/wiki/TableDeclarationSyntax

% Dimitri Yatsenko, 2009-2011.

classdef (Sealed) Table < handle
    
    properties(SetAccess = private)
        schema   % handle to a schema object
        info     % name, tier, comment.  See self.Schema
        attrs    % structure array describing attrs
        className    % the name of the class that should be associated with this table
    end
    properties(Access=private)
        updateListener   % listens for schema definition changes
    end
    
    
    methods
        function self = Table(className)
            % obj = dj.Table('package.className')
            self.className = className;
            assert(nargin==1 && ischar(self.className),  ...
                'dj.Table requres input ''package.ClassName''')
            assert(~isempty(regexp(self.className,'\w+\.[A-Z]\w+','once')), ...
                'invalid table identification ''%s''. Should be package.ClassName', ...
                self.className)
            schemaFunction = regexprep(self.className, '\.\w+$', '.getSchema');
            assert(~isempty(which(schemaFunction)), ['Not found: ' schemaFunction])
            self.schema = eval(schemaFunction);
            self.updateListener = event.listener(self.schema, ...
                'ChangedDefinitions', @(eventSrc,eventData) self.reset);
            assert(isa(self.schema, 'dj.Schema'), ...
                [schemaFunction ' must return an instance of dj.Schema'])
        end
        
        
        function init(self)
            if isempty(self.info)
                
                % find table in the schema
                ix = strcmp(self.className, self.schema.classNames);
                if ~any(ix)
                    % table does not exist. Create it.
                    self.create
                    ix = strcmp(self.className, self.schema.classNames);
                    assert(any(ix), 'Table %s is not found', self.className);
                end
                
                % table exists, initialize
                self.info = self.schema.tables(ix);
                self.attrs = self.schema.attrs(strcmp(self.info.name, ...
                    {self.schema.attrs.table}));
            end
        end
        
        
        function reset(self)
            % undo the effect of self.init
            self.info = [];
            self.attrs = [];
        end
        
        
        function display(self)
            self.init
            display@handle(self)
            disp(self.re(true))
            fprintf \n
        end
        
        
        
        function erd(self, varargin)
            % dj.Table/erd - plot the entity relationship diagram of tables
            % that are connected to self.
            %
            % SYNTAX
            %   table.erd([depth1[,depth2]])
            %
            % depth1 and depth2 specify the connectivity radius upstream
            % (depth<0) and downstream (depth>0) of this table.
            % Omitting both depths defaults to table.erd(-2,2).
            % Omitting any one of the depths sets it to zero.
            %
            % Examples:
            %   t = dj.Table('vis2p.Scans');
            %   t.erd       % plot two levels above and below
            %   t.erd( 2);  % plot dependents up to 2 levels below
            %   t.erd(-1);  % plot only immediate ancestors
            %
            % See also dj.Schema/erd
            self.init
            self.schema.erd(self.schema.getNeighbors(self.className, varargin{:}))
        end
        
        
        
        function str = re(self, expandForeignKeys)
            % dj.Table/re - "reverse engineer" the table declaration.
            %
            % SYNTAX:
            %   str = table.re
            %   str = table.re(true)
            %
            % str will contain the table declaration string that can be used
            % to create the table using dj.Table.
            %
            % When the second input expandForeignKeys is true, then references
            % to other tables are not displayed and foreign key attrs are shown
            % as regular attrs.
            %
            % See also dj.Table
            
            self.init
            
            expandForeignKeys = nargin>=2 && expandForeignKeys;
            
            if expandForeignKeys
                str = '';
            else
                str = sprintf('%%{\n');
            end
            str = sprintf('%s%s (%s) # %s\n', ...
                str, self.className, self.info.tier, self.info.comment);
            tableIdx = find(strcmp(self.schema.classNames, self.className));
            assert(~isempty(tableIdx), ...
                'class %s does not appear in the class list of the schema', self.className);
            
            keyFields = {self.attrs([self.attrs.iskey]).name};
            
            if ~expandForeignKeys
                % list parent references
                if size(self.schema.dependencies,1) >= tableIdx
                    refIds = find(self.schema.dependencies(tableIdx,:)==1);
                    for i=refIds
                        str = sprintf('%s\n-> %s',str, self.schema.classNames{i});
                        excludeFields = {self.schema.attrs([self.schema.attrs.iskey]...
                            & strcmp({self.schema.attrs.table},self.schema.tables(i).name)).name};
                        keyFields = keyFields(~ismember(keyFields, excludeFields));
                    end
                end
            end
            
            for i=find(ismember({self.attrs.name}, keyFields))
                comment = self.attrs(i).comment;
                str = sprintf('%s\n%-40s# %s', str, ...
                    sprintf('%-16s: %s', self.attrs(i).name, self.attrs(i).type), ...
                    comment);
            end
            
            % dividing line
            str = sprintf('%s\n---', str);
            
            dependentFields = {self.attrs(~[self.attrs.iskey]).name};
            
            % list other references
            if ~expandForeignKeys
                if size(self.schema.dependencies, 2) >= tableIdx
                    refIds = find(self.schema.dependencies(tableIdx,:)==2);
                    for i=refIds
                        str = sprintf('%s\n-> %s',str, self.schema.classNames{i});
                        excludeFields = {self.schema.attrs([self.schema.attrs.iskey]...
                            & strcmp({self.schema.attrs.table},self.schema.tables(i).name)).name};
                        dependentFields = dependentFields(~ismember(dependentFields, excludeFields));
                    end
                end
            end
            
            % list remaining attrs
            for i=find(ismember({self.attrs.name}, dependentFields))
                if self.attrs(i).isnullable
                    default = '=null';
                elseif strcmp(char(self.attrs(i).default(:)'), '<<<none>>>')
                    default = '';
                elseif self.attrs(i).isNumeric || strcmp(self.attrs(i).default,'CURRENT_TIMESTAMP')
                    default = ['=' self.attrs(i).default];
                else
                    default = ['="' self.attrs(i).default '"'];
                end
                comment = self.attrs(i).comment;
                str = sprintf('%s\n%-60s# %s', str, ...
                    sprintf('%-28s: %s', [self.attrs(i).name default], self.attrs(i).type), ...
                    comment);
            end
            str = sprintf('%s\n', str);
            
            if ~expandForeignKeys
                str = sprintf('%s%%}\n', str);
            end
        end
        
        
        function optimize(self)
            % optimizes the table if it has become fragmented after repeated inserts and deletes.  
            % See http://dev.mysql.com/doc/refman/5.6/en/optimize-table.html
            self.init
            fprintf 'optimizing ...'
            status = self.schema.query(sprintf('OPTIMIZE LOCAL TABLE `%s`.`%s`', ...
                self.schema.dbname, self.info.name));
            disp(status.Msg_text{end})
        end
            
        
        
        function alter(self)
            % dj.Table/alter - alter the table definition
            %
            % Datajoint tables are defined in the first percent-brace block
            % comment of the file <package>.<className>.m.
            %
            % If the new table definition matches the current definition,
            % dj.Table/alter does nothing.
            %
            % If the table is empty, the table and its dependents are
            % simply dropped.  The tables will then be recreated automatically
            % upon next use.
            %
            % If the table is not empty, dj.Table/alter compares the column
            % definitions. If a column name is not present in the new definition,
            % dj.Table/alter will prompt the user to match it to a new column or
            % to drop it altogether.  For new columns that are not matched to
            % existing columns and do not have a default value, dj.Table/alter
            % prompts the user to provide a temporary default value that is
            % applied only once during the transition.
            %
            % Any alterations of the primary key are propagated to the dependent
            % tables.  The database will reject this operation if referential
            % constraints are caused to be violated.
            
            if ~count(dj.Relvar(self))
                % if empty, simply drop the table
                self.drop
            else
                keyChange = false;
                [tableInfo parents references fieldDefs] = ...
                    dj.Table.parseDeclaration(self.getDeclaration);
                tableIdx = find(strcmp(self.schema.classNames, self.className), 1, 'first');
                parentIdx = find(self.schema.dependencies(tableIdx,:)==1);
                error 'not implemented yet'
            end
        end
        
        
        
        
        function drop(self)
            % dj.Table/drop - drop the table and all its dependents.
            % Confirmation is requested if the dropped tables contain data.
            %
            % Although drop reloads the schema information upon completion,
            % "clear classes" may be necessary to remove constant object
            % properties and persistent variables that refer to the dropped
            % table.
            %
            % See also dj.Table, dj.Relvar/del
            
            self.init
            self.schema.cancelTransaction   % exit ongoing transaction
            
            % warn user if self is a subtable
            if ismember(self.info.tier, {'imported','computed'}) && ...
                    ~isempty(which(self.className))
                rel = eval(self.className);
                if ~isa(rel,'dj.AutoPopulate')
                    fprintf(['\n!!! %s is a subtable. For referential integrity, ' ...
                        'drop its parent table instead.\n'], self.className)
                    if ~strcmpi('yes', input('Proceed anyway? yes/no >','s'))
                        fprintf '\ndrop cancelled\n\n'
                        return
                    end
                end
            end
            
            % comple the list of dependent tables
            downstream = self.schema.getNeighbors(self.className, 0, +1000, false);
            
            % inform user about what's being deleted
            fprintf 'ABOUT TO DROP TABLES: \n'
            names = cell(size(downstream));
            counts = zeros(size(downstream));
            for iTable = 1:length(downstream)
                names{iTable} = sprintf('`%s`.`%s`', ...
                    self.schema.dbname, self.schema.tables(downstream(iTable)).name);
                n = self.schema.query(sprintf('SELECT count(*) as n FROM %s', ...
                    names{iTable}));
                counts(iTable) = n.n;
                fprintf('%s... %d tuples \n', names{iTable}, n.n)
            end
            fprintf \n
            
            % if any table has data, give option to cancel
            doDrop = ~any(counts) || ...
                strncmpi('yes', input('Proceed to drop? yes/no >', 's'), 3);
            if ~doDrop
                disp 'User cancelled table drop'
            else
                for iTable = length(downstream):-1:1
                    self.schema.query(sprintf('DROP TABLE %s', names{iTable}))
                    fprintf('Dropped table %s\n', ...
                        self.schema.classNames{downstream(iTable)})
                end
                % reload the schema.  clear classes is still necessary to reset
                % constant properties and persistent variables that use the
                % dropped tables
                self.schema.reload
            end
            fprintf \n
        end
    end
    
    
    
    methods(Access=private)

        function declaration = getDeclaration(self)          
            file = which(self.className);
            assert(~isempty(file), 'DataJoint:MissingTableDefnition', ...
                'Could not find table definition file %s', file)
            declaration = dj.utils.readPercentBraceComment(file);
            assert(~isempty(declaration), 'DataJoint:MissingTableDefnition', ...
                'Could not find the table declaration in %s', file)
        end

        
        function create(self)     

            [tableInfo parents references fieldDefs] = ...
                dj.Table.parseDeclaration(self.getDeclaration);
            cname = sprintf('%s.%s', tableInfo.package, tableInfo.className);
            assert(strcmp(cname, self.className), ...
                'Table name %s does not match in file %s', cname, self.className)           
            
            % compile the CREATE TABLE statement
            tableName = [...
                dj.utils.tierPrefixes{strcmp(tableInfo.tier, dj.utils.allowedTiers)}, ...
                dj.utils.camelCase(tableInfo.className, true)];
            
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', self.schema.dbname, tableName);
            
            % add inherited primary key attrs
            primaryKeyFields = {};
            for iRef = 1:length(parents)
                for iField = find([parents{iRef}.table.attrs.iskey])
                    field = parents{iRef}.table.attrs(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        primaryKeyFields{end+1} = field.name;   %#ok<AGROW>
                        assert(~field.isnullable, 'primary key attrs cannot be nullable')
                        sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                    end
                end
            end
            
            % add the new primary key attrs
            if ~isempty(fieldDefs)
                for iField = find([fieldDefs.iskey])
                    field = fieldDefs(iField);
                    primaryKeyFields{end+1} = field.name;  %#ok<AGROW>
                    assert(~strcmpi(field.default,'NULL'), ...
                        'primary key attrs cannot be nullable')
                    sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                end
            end
            
            % add secondary foreign key attrs
            for iRef = 1:length(references)
                for iField = find([references{iRef}.table.attrs.iskey])
                    field = references{iRef}.table.attrs(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                    end
                end
            end
            
            % add dependent attrs
            if ~isempty(fieldDefs)
                for iField = find(~[fieldDefs.iskey])
                    field = fieldDefs(iField);
                    sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                end
            end
            
            % add primary key declaration
            assert(~isempty(primaryKeyFields), ...
                'table must have a primary key');
            str = sprintf(',`%s`', primaryKeyFields{:});
            sql = sprintf('%sPRIMARY KEY (%s),\n',sql, str(2:end));
            
            % add foreign key declarations
            indices = {primaryKeyFields};
            for ref = [parents, references]
                fieldList = sprintf('%s,', ref{1}.primaryKey{:});
                fieldList(end)=[];
                if ~any(cellfun(@(x) isequal(ref{1}.primaryKey, x(1:min(end,length(ref{1}.primaryKey)))), indices));
                    % add index if necessary. From MySQL manual:
                    % "In the referencing table, there must be an index where the foreign
                    % key columns are listed as the first columns in the same order."
                    % http://dev.mysql.com/doc/refman/5.6/en/innodb-foreign-key-constraints.html
                    sql = sprintf('%sINDEX (%s),\n', sql, fieldList);
                    indices{end+1} = ref{1}.primaryKey;  %#ok<AGROW>
                end
                sql = sprintf(...
                    '%sCONSTRAINT FOREIGN KEY (%s) REFERENCES `%s`.`%s` (%s) ON UPDATE CASCADE ON DELETE RESTRICT,\n', ...
                    sql, fieldList, ref{1}.table.schema.dbname, ref{1}.table.info.name, fieldList);
            end
            
            % close the declaration
            sql = sprintf('%s\n) ENGINE = InnoDB, COMMENT "%s$"', sql(1:end-2), tableInfo.comment);
            
            fprintf \n<SQL>\n
            disp(sql)
            fprintf </SQL>\n\n
            
            % execute declaration
            if nargout==0
                self.schema.query(sql);
            end
            self.schema.reload
        end       
    end
    
    methods(Static, Access=private)               
        
        function sql = fieldToSQL(field)
            % convert the structure field with attrs {'name' 'type' 'default' 'comment'}
            % to the SQL column declaration
            
            if strcmpi(field.default, 'NULL')
                % all nullable attrs default to null
                field.default = 'DEFAULT NULL';
            else
                if strcmp(field.default,'<<<none>>>')
                    field.default = 'NOT NULL';
                else
                    % enclose value in quotes (even numeric), except special SQL values
                    if ~strcmpi(field.default, 'CURRENT_TIMESTAMP') && ...
                            ~any(strcmp(field.default([1 end]), {'''''','""'}))
                        field.default = ['"' field.default '"'];
                    end
                    field.default = sprintf('NOT NULL DEFAULT %s', field.default);
                end
            end
            sql = sprintf('`%s` %s %s COMMENT "%s",\n', ...
                field.name, field.type, field.default, field.comment);
        end
        
        
        function [tableInfo parents references fieldDefs] = parseDeclaration(declaration)
            parents = {};
            references = {};
            fieldDefs = [];
            
            if ischar(declaration)
                declaration = dj.utils.str2cell(declaration);
            end
            assert(iscellstr(declaration), ...
                'declaration must be a multiline string or a cellstr');
            
            % remove empty lines
            declaration(cellfun(@(x) isempty(strtrim(x)), declaration)) = [];
            
            % expand <<macros>>   TODO: make macro expansion recursive (if necessary)
            for macro = fieldnames(dj.utils.macros)'
                while true
                    ix = find(strcmp(strtrim(declaration), ...
                        ['<<' macro{1} '>>']),1,'first');
                    if isempty(ix)
                        break
                    end
                    declaration = [
                        declaration(1:ix-1)
                        dj.utils.macros.(macro{1})
                        declaration(ix+1:end)
                        ];
                end
            end
            
            % concatenate lines that end with a backslash to the next line
            i = 1;
            while i<length(declaration)
                pos = regexp(declaration{i},  '\\\s*$', 'once');
                if isempty(pos)
                    i = i + 1;
                else
                    declaration{i} = [strtrim(declaration{i}(1:pos-1)) ' ' ...
                        strtrim(declaration{i+1})];
                    declaration(i+1) = [];
                end
            end
            
            % parse table schema, name, type, and comment
            pat = {
                '^\s*(?<package>\w+)\.(?<className>\w+)\s*'  % package.TableName
                '\(\s*(?<tier>\w+)\s*\)\s*'                  % (tier)
                '#\s*(?<comment>\S.*\S)\s*$'                 % # comment
                };
            tableInfo = regexp(declaration{1}, cat(2,pat{:}), 'names');
            assert(numel(tableInfo)==1, ...
                'incorrect syntax is table declaration, line 1')
            assert(ismember(tableInfo.tier, dj.utils.allowedTiers),...
                ['Invalid tier for table ' tableInfo.className])
            
            if nargout > 1
                % parse field declarations and references
                inKey = true;
                for iLine = 2:length(declaration)
                    line = strtrim(declaration{iLine});
                    switch true
                        case strncmp(line,'---',3)
                            inKey = false;
                        case strncmp(line,'->',2)
                            % foreign key
                            p = eval(line(3:end));
                            assert(isa(p, 'dj.Relvar'), ...
                                'foreign keys must be base relvars')
                            if inKey
                                parents{end+1} = p;     %#ok:<AGROW>
                            else
                                references{end+1} = p;   %#ok:<AGROW>
                            end
                        otherwise
                            % parse field definition
                            pat = {
                                '^\s*(?<name>[a-z][a-z\d_]*)\s*'  % field name
                                '=\s*(?<default>\S+(\s+\S+)*)\s*' % default value
                                ':\s*(?<type>\w[^#]*\S)\s*'       % datatype
                                '#\s*(?<comment>\S||\S.*\S)\s*$'  % comment
                                };
                            fieldInfo = regexp(line, cat(2,pat{:}), 'names');
                            if isempty(fieldInfo)
                                % try no default value
                                fieldInfo = regexp(line, cat(2,pat{[1 3 4]}), 'names');
                                assert(~isempty(fieldInfo), ...
                                    'invalid field declaration line: %s', line);
                                fieldInfo.default = '<<<none>>>';
                            end
                            assert(~any(fieldInfo.comment=='"'), ...
                                'comments must not contain double quotes')
                            assert(numel(fieldInfo)==1, ...
                                'Invalid field declaration "%s"', line);
                            fieldInfo.iskey = inKey;
                            fieldDefs = [fieldDefs fieldInfo];  %#ok:<AGROW>
                    end
                end
            end
        end
    end
end
