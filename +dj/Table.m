% dj.Table provides the data definition interface to a single table in the
% database.
%
% Initialization:
%    table = dj.Table('package.ClassName')
%
% If the table does not exist, it is created based on the definition
% specified in the first multi-line percent-brace comment block
% of +package/ClassName.m
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
        schema           % handle to a schema object
        info             % name, tier, comment.  See self.Schema
        primaryKey       % a column cell array containing primary key names
        fields           % structure array describing fields
    end
    
    methods
        function self = Table(className)
            % obj = dj.Table('package.className')
            assert(nargin==1 && ischar(className),  ...
                'dj.Table requres input ''package.ClassName''')
            assert(~isempty(regexp(className,'\w+\.[A-Z]\w+','once')), ...
                'invalid table identification ''%s''. Should be package.ClassName', ...
                className)
            schemaFunction = regexprep(className, '\.\w+$', '.getSchema');
            self.schema = eval(schemaFunction);
            assert(isa(self.schema, 'dj.Schema'), ...
                [schemaFunction ' must return an instance of dj.Schema']);
            
            % find table in the schema
            ix = strcmp(className, self.schema.classNames);
            if ~any(ix)
                % table does not exist. Create it.
                path = which(className);
                assert(~isempty(path), [className ' not found']');
                declaration = dj.utils.readPreamble(path);
                if ~isempty(declaration)
                    try
                        dj.Table.create(declaration);
                        self.schema.reload
                        ix = strcmp(className, self.schema.classNames);
                    catch e
                        fprintf('!!! Error while parsing the table declaration for %s:\n%s\n', ...
                            className, e.message)
                        rethrow(e)
                    end
                    
                end
                assert(any(ix), 'Table %s is not found', className);
            end
            
            % table exists, initialize
            self.info = self.schema.tables(ix);
            self.fields = self.schema.fields(strcmp(self.info.name, ...
                {self.schema.fields.table}));
            self.primaryKey = {self.fields([self.fields.iskey]).name};
        end
        
        
        
        function display(self)
            display@handle(self)
            disp(self.re(true))
            fprintf \n
        end
        
        
        function str = getClassname(self)
            % dj.Table.getClassname - returns the class name for the
            % table's dj.Relvar
            str = sprintf('%s.%s', self.schema.package, dj.utils.camelCase(self.info.name));
        end
        
        
        
        function erd(self, depth1, depth2)
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
            
            switch nargin
                case 1
                    levels = [-2 2];
                case 2
                    levels = sort([0 depth1]);
                case 3
                    levels = sort([depth1 depth2]);
            end
            
            i = find(strcmp({self.schema.tables.name}, self.info.name));
            assert(length(i) == 1);
            
            % find tables on which self depends
            upstream = i;
            nodes = i;
            for j=1:-levels(1)
                [~, nodes] = find(self.schema.dependencies(nodes,:));
                upstream = [upstream nodes(:)'];  %#ok:<AGROW>
            end
            
            % find tables dependent on self
            downstream = [];
            nodes = i;
            for j=1:levels(2)
                [nodes, ~] = find(self.schema.dependencies(:, nodes));
                downstream = [downstream nodes(:)'];  %#ok:<AGROW>
            end
            
            % plot the ERD
            self.schema.erd(unique([upstream downstream]))
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
            % to other tables are not displayed and foreign key fields are shown
            % as regular fields.
            %
            % See also dj.Table
            
            expandForeignKeys = nargin>=2 && expandForeignKeys;
            
            className = [self.schema.package '.' dj.utils.camelCase(self.info.name)];
            if expandForeignKeys
                str = '';
            else
                str = sprintf('<BEGIN DECLARATION CODE>\n%%{\n');
            end
            str = sprintf('%s%s (%s) # %s\n', ...
                str, className, self.info.tier, self.info.comment);
            tableIdx = find(strcmp(self.schema.classNames, className));
            assert(~isempty(tableIdx), ...
                'class %s does not appear in the class list of the schema', className);
            
            keyFields = {self.fields([self.fields.iskey]).name};
            
            if ~expandForeignKeys
                % list parent references
                if size(self.schema.dependencies,1) >= tableIdx
                    refIds = find(self.schema.dependencies(tableIdx,:)==1);
                    for i=refIds
                        str = sprintf('%s\n-> %s',str, self.schema.classNames{i});
                        excludeFields = {self.schema.fields([self.schema.fields.iskey]...
                            & strcmp({self.schema.fields.table},self.schema.tables(i).name)).name};
                        keyFields = keyFields(~ismember(keyFields, excludeFields));
                    end
                end
            end
            
            for i=find(ismember({self.fields.name}, keyFields))
                comment = self.fields(i).comment;
                str = sprintf('%s\n%-40s# %s', str, ...
                    sprintf('%-16s: %s', self.fields(i).name, self.fields(i).type), ...
                    comment);
            end
            
            % dividing line
            str = sprintf('%s\n---', str);
            
            dependentFields = {self.fields(~[self.fields.iskey]).name};
            
            % list other references
            if ~expandForeignKeys
                if size(self.schema.dependencies, 2) >= tableIdx
                    refIds = find(self.schema.dependencies(tableIdx,:)==2);
                    for i=refIds
                        str = sprintf('%s\n-> %s',str, self.schema.classNames{i});
                        excludeFields = {self.schema.fields([self.schema.fields.iskey]...
                            & strcmp({self.schema.fields.table},self.schema.tables(i).name)).name};
                        dependentFields = dependentFields(~ismember(dependentFields, excludeFields));
                    end
                end
            end
            
            % list remaining fields
            for i=find(ismember({self.fields.name}, dependentFields))
                if self.fields(i).isnullable
                    default = '=null';
                elseif strcmp(char(self.fields(i).default(:)'), '<<<none>>>')
                    default = '';
                elseif self.fields(i).isNumeric || strcmp(self.fields(i).default,'CURRENT_TIMESTAMP')
                    default = ['=' self.fields(i).default];
                else
                    default = ['="' self.fields(i).default '"'];
                end
                comment = self.fields(i).comment;
                str = sprintf('%s\n%-60s# %s', str, ...
                    sprintf('%-28s: %s', [self.fields(i).name default], self.fields(i).type), ...
                    comment);
            end
            str = sprintf('%s\n', str);
            
            if ~expandForeignKeys
                str = sprintf('%s%%}\n', str);
                str = sprintf('%s<END DECLARATION CODE>\n',str);
            end
            
            % if no output argument, then print to stdout
            if nargout==0
                fprintf('\n%s\n', str)
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
            
            self.schema.cancelTransaction   % exit ongoing transaction
            
            % warn user if self is a subtable
            if ismember(self.info.tier, {'imported','computed'}) && ...
                    ~isempty(which(self.getClassname))
                rel = eval(self.getClassname);
                if ~isa(rel,'dj.AutoPopulate')
                    fprintf(['\n!!! %s is a subtable. For referential integrity, ' ...
                        'drop its parent table instead.\n'], self.getClassname)
                    if ~strcmpi('yes', input('Proceed anyway? yes/no >','s'))
                        fprintf '\ndrop cancelled\n\n'
                        return
                    end                    
                end
            end
            
            % comple the list of dependent tables
            nodes = find(strcmp({self.schema.tables.name}, self.info.name));
            assert(~isempty(nodes));
            downstream = nodes;
            while ~isempty(nodes)
                [nodes, ~] = find(self.schema.dependencies(:, nodes));
                nodes = setdiff(nodes, downstream);
                downstream = [downstream nodes(:)'];  %#ok:<AGROW>
            end
            
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
    
    
    
    methods(Static, Access=private)
        
        function sql = create(declaration)
            % create a new table
            disp 'CREATING TABLE IN THE DATABASE: '
            
            [tableInfo parents references fieldDefs] = dj.Table.parseDeclaration(declaration);
            schemaObj = eval(sprintf('%s.getSchema', tableInfo.package));
            
            % compile the CREATE TABLE statement
            tableName = [...
                dj.utils.tierPrefixes{strcmp(tableInfo.tier, dj.utils.allowedTiers)}, ...
                dj.utils.camelCase(tableInfo.className, true)];
            
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', schemaObj.dbname, tableName);
            
            % add inherited primary key fields
            primaryKeyFields = {};
            for iRef = 1:length(parents)
                for iField = find([parents{iRef}.fields.iskey])
                    field = parents{iRef}.fields(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        primaryKeyFields{end+1} = field.name;   %#ok<AGROW>
                        assert(~field.isnullable, 'primary key fields cannot be nullable')
                        sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                    end
                end
            end
            
            % add the new primary key fields
            if ~isempty(fieldDefs)
                for iField = find([fieldDefs.iskey])
                    field = fieldDefs(iField);
                    primaryKeyFields{end+1} = field.name;  %#ok<AGROW>
                    assert(~strcmpi(field.default,'NULL'), ...
                        'primary key fields cannot be nullable')
                    sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                end
            end
            
            % add secondary foreign key fields
            for iRef = 1:length(references)
                for iField = find([parents{iRef}.fields.iskey])
                    field = references{iRef}.fields(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        sql = sprintf('%s%s', sql, dj.Table.fieldToSQL(field));
                    end
                end
            end
            
            % add dependent fields
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
                    sql, fieldList, ref{1}.schema.dbname, ref{1}.table.info.name, fieldList);
            end
            
            % close the declaration
            sql = sprintf('%s\n) ENGINE = InnoDB, COMMENT "%s$"', sql(1:end-2), tableInfo.comment);
            
            fprintf \n<SQL>\n
            disp(sql)
            fprintf </SQL>\n\n
            
            % execute declaration
            if nargout==0
                schemaObj.query(sql);
            end
        end
        
        
        function sql = fieldToSQL(field)
            % convert the structure field with fields {'name' 'type' 'default' 'comment'}
            % to the SQL column declaration
            
            if strcmpi(field.default, 'NULL')
                % all nullable fields default to null
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
                                '^\s*(?<name>[a-z][a-z0-9_]*)\s*' % field name
                                '=\s*(?<default>\S+(\s+\S+)*)\s*' % default value
                                ':\s*(?<type>\w+([^#"]+|"[^"]*")*\S)\s*' % datatype
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
