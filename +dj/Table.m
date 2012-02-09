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
        className    % the name of the corresponding base dj.Relvar class
    end
    
    properties(Dependent, SetAccess = private)
        info     % name, tier, comment.  See self.Schema
        attrs    % structure array describing attrs
    end
    
    properties(Constant)
        mysql_constants = {'CURRENT_TIMESTAMP','CURRENT_TIME','CURRENT_DATE'}
    end
    
    
    methods
        function self = Table(className)
            % obj = dj.Table('package.className')
            self.className = className;
            assert(nargin==1 && ischar(self.className),  ...
                'dj.Table requres input ''package.ClassName''')
            assert(~isempty(regexp(self.className,'^\w+\.[A-Z]\w+','once')), ...
                'invalid table identification ''%s''. Should be package.ClassName', ...
                self.className)
        end
        
        
        function ret = get.schema(self)
            if isempty(self.schema)
                schemaFunction = regexprep(self.className, '\.\w+$', '.getSchema');
                assert(~isempty(which(schemaFunction)), ['Not found: ' schemaFunction])
                self.schema = eval(schemaFunction);
                assert(isa(self.schema, 'dj.Schema'), ...
                    [schemaFunction ' must return an instance of dj.Schema'])
            end
            ret = self.schema;
        end
        
        
        function info = get.info(self)
            ix = strcmp(self.className, self.schema.classNames);
            if ~any(ix)   % table does not exist. Create it.
                self.create
                ix = strcmp(self.className, self.schema.classNames);
                assert(any(ix), 'Table %s is not found', self.className);
            end
            info = self.schema.tables(ix);
        end
        
        
        function attrs = get.attrs(self)
            attrs = self.schema.attrs(strcmp(self.info.name, {self.schema.attrs.table}));
        end
        
        
        function name = getFullTableName(self)
            name = sprintf('`%s`.`%s`', self.schema.dbname, self.info.name);
        end
        
        function display(self)
            display@handle(self)
            disp(self.re(true))
            fprintf \n
        end
        
        
        function neighbors = getNeighbors(self, depth1, depth2, crossSchemas)
            % dj.Table/getNeighbors -- get the class names of tables that are
            % directly related to the given table.
            %
            % depth1 and depth2 specify the connectivity radius upstream
            % (depth<0) and downstream (depth>0) of this table.
            % Omitting both depths defaults to (-2,2).
            % Omitting any one of the depths sets it to zero.
            %
            % If interSchma is set to true, the search cascades into other
            % schema.
            %
            % Examples:
            %   table.getNeighbors(-1,0)     % get table's parents
            %   table.getNeighbors(0,1)      % get table's children
            %   table.getNeighbors(-2,2)     % two levels up and down
            
            crossSchemas = nargin>=4 && crossSchemas;
            
            % find tables on which self depends
            upstream = {};
            nodes = {self.className};
            for j=1:-depth1
                nodes = self.schema.getParents(nodes,[1 2],crossSchemas);
                if isempty(nodes)
                    break
                end
                upstream = setdiff(upstream, nodes);
                upstream = [nodes upstream];  %#ok:<AGROW>
            end
            
            % find tables dependent on self
            downstream = {};
            nodes = {self.className};
            for j=1:depth2
                nodes = self.schema.getChildren(nodes,[1 2],crossSchemas);
                if isempty(nodes)
                    break;
                end
                nodes = setdiff(nodes, downstream);
                downstream = [downstream nodes];  %#ok:<AGROW>
            end
            
            neighbors = [upstream {self.className} downstream];
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
                    depth1 = -2;
                    depth2 = +2;
                case 2
                    depth2 = max(0, depth1);
                    depth1 = min(0, depth1);
            end

            self.schema.erd(self.getNeighbors(depth1, depth2))
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
            
            expandForeignKeys = nargin>=2 && expandForeignKeys;
            
            if expandForeignKeys
                str = '';
            else
                str = sprintf('%%{\n');
            end
            str = sprintf('%s%s (%s) # %s\n', ...
                str, self.className, self.info.tier, self.info.comment);
            assert(any(strcmp(self.schema.classNames, self.className)), ...
                'class %s does not appear in the class list of the schema', self.className);
            
            keyFields = {self.attrs([self.attrs.iskey]).name};
            
            if ~expandForeignKeys
                % list parent references
                for refClassName = self.schema.getParents(self.className, 1)
                    refObj = dj.Table(refClassName{1});
                    str = sprintf('%s\n-> %s',str, refClassName{1});
                    excludeFields = {refObj.attrs([refObj.attrs.iskey]).name};
                    keyFields = keyFields(~ismember(keyFields, excludeFields));
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
                for refClassName = self.schema.getParents(self.className, 2)
                    refObj = dj.Table(refClassName);
                    str = sprintf('%s\n-> %s',str, refClassName);
                    excludeFields = {refObj.attrs([refObj.attrs.iskey]).name};
                    dependentFields = dependentFields(~ismember(dependentFields, excludeFields));
                end
            end
            
            % list remaining attrs
            for i=find(ismember({self.attrs.name}, dependentFields))
                if self.attrs(i).isnullable
                    default = '=null';
                elseif strcmp(char(self.attrs(i).default(:)'), '<<<none>>>')
                    default = '';
                elseif self.attrs(i).isNumeric || ...
                        any(strcmp(self.attrs(i).default,self.mysql_constants))
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
            fprintf 'optimizing ...'
            status = query(dj.conn, sprintf('OPTIMIZE LOCAL TABLE `%s`.`%s`', ...
                self.schema.dbname, self.info.name));
            disp(status.Msg_text{end})
        end
        
        
        
        
        
        %%%%% ALTER METHODS: change table definitions %%%%%%%%%%%%
        function alterTableComment(self, newComment)
            % dj.Table/alterTableComment - update the table comment
            % in the table declaration
            query(dj.conn, ...
                sprintf('ALTER TABLE `%s`.`%s` COMMENT = "%s"', ...
                self.schema.dbname, self.info.name, newComment));
            disp 'table updated'
            self.syncDef
        end
        
        function addAttribute(self, definition)
            sql = fieldToSQL(parseAttrDef(definition, false));
            sql = sprintf('ALTER TABLE `%s`.`%s` ADD COLUMN %s', ...
                self.schema.dbname, self.info.name, sql(1:end-2));
            query(dj.conn, sql)
            disp 'table updated'
            self.schema.reload
            self.syncDef
        end
        
        function dropAttribute(self, attrName)
            sql = sprintf('ALTER TABLE `%s`.`%s` DROP COLUMN %s', ...
                self.schema.dbname, self.info.name, attrName);
            query(dj.conn, sql)
            disp 'table updated'
            self.schema.reload
            self.syncDef
        end
        
        function alterAttribute(self, attrName, newDefinition)
            sql = fieldToSQL(parseAttrDef(newDefinition, false));
            sql = sprintf('ALTER TABLE `%s`.`%s` CHANGE COLUMN %s %s', ...
                self.schema.dbname, self.info.name, attrName, sql(1:end-2));
            query(dj.conn, sql)
            disp 'table updated'
            self.schema.reload
            self.syncDef
        end
        
        
        
        function syncDef(self)
            % dj.Table/syncDef replace the table declaration in the file
            % <package>.<className>.m with the actual definition from the database.
            %
            % This method is useful if the table definition has been
            % changed by other means than the regular datajoint definition
            % process.
            
            path = which(self.className);
            if isempty(path)
                fprintf('File %s.m is not found\n', self.className);
            else
                s = input(sprintf('Update table declaration in %s? yes/no > ',path), 's');
                if ~strcmpi(s,'yes')
                    disp 'No? Table declaration left unpdated.'
                else
                    % read old file
                    f = fopen(path, 'rt');
                    lines = {};
                    line = fgetl(f);
                    while ischar(line)
                        lines{end+1} = line;  %#ok<AGROW>
                        line = fgetl(f);
                    end
                    fclose(f);
                    
                    % write new file
                    f = fopen(path, 'wt');
                    p1 = find(strcmp(strtrim(lines), '%{'), 1, 'first');
                    p2 = find(strcmp(strtrim(lines), '%}'), 1, 'first');
                    if isempty(p1)
                        p1 = 1;
                        p2 = 1;
                    end
                    for i=1:p1-1
                        fprintf(f,'%s\n',lines{i});
                    end
                    fprintf(f,'%s', self.re);
                    for i=p2+1:length(lines)
                        fprintf(f,'%s\n',lines{i});
                    end
                    fclose(f);
                    disp 'updated table definition'
                end
            end
        end
        %%%%%  END ALTER METHODS
        
        
        
        
        %         function list = getAllDependents(self)
        %             % dj.Table/getAllDependents - get all dependent tables across all schemas.
        %             % This is used by dj.Table/drop and dj.Table/delete to properly
        %             % their effects.
        %
        %             expanded = {self.schema.dbname, self.info.name};
        %             list = {};
        %             while ~isempty(expanded)
        %                 list = {list; expanded}
        %                 cond = sprintf(' OR referenced_table_schema="%s" AND referenced_table_name="%s"', expanded{:});
        %                 foreignKeys = query(dj.conn, [...
        %                     'SELECT table_schema as `schema`, table_name AS `table`', ...
        %                     ' FROM information_schema.key_column_usage ', ...
        %                     sprintf('WHERE FALSE %s',cond) ...
        %                     ' GROUP BY table_schema, table_name']));
        %                 expanded = [{foregnKeys.schema}, {foreignKeys.table}];
        %             end
        %
        %         end
        
        
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
            
            self.schema.conn.cancelTransaction   % exit ongoing transaction
            
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
            
            % compile the list of dropped tables
            names = self.getNeighbors(0, +1000, true);
            names = cellfun(@(x) self.schema.conn.getPackage(x), names, 'uni', false);
            names = [{self.getFullTableName}, ...
                cellfun(@(x) getFullTableName(dj.Table(x)), names(2:end), 'uni', false)];
            
            % inform user about what's being deleted
            fprintf 'ABOUT TO DROP TABLES: \n'
            counts = zeros(size(names));
            for iTable = 1:length(names)
                n = query(dj.conn, sprintf('SELECT count(*) as n FROM %s', ...
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
                try
                    for iTable = length(names):-1:1
                        query(dj.conn, sprintf('DROP TABLE %s', names{iTable}))
                        fprintf('Dropped table %s\n', names{iTable})
                    end
                catch err
                    self.schema.conn.reload
                    rethrow(err)
                end
                % reload all schemas
                self.schema.conn.reload
            end
            fprintf \n
        end       
    end
    
    
    
    
    
    methods(Access=private)
        
        
        function declaration = getDeclaration(self)
            file = which(self.className);
            assert(~isempty(file), 'DataJoint:MissingTableDefnition', ...
                'Could not find table definition file %s', file)
            declaration = dj.common.readPercentBraceComment(file);
            assert(~isempty(declaration), 'DataJoint:MissingTableDefnition', ...
                'Could not find the table declaration in %s', file)
        end
        
        
        function create(self)
            
            [tableInfo parents references fieldDefs] = ...
                parseDeclaration(self.getDeclaration);
            cname = sprintf('%s.%s', tableInfo.package, tableInfo.className);
            assert(strcmp(cname, self.className), ...
                'Table name %s does not match in file %s', cname, self.className)
            
            % compile the CREATE TABLE statement
            tableName = [...
                dj.common.tierPrefixes{strcmp(tableInfo.tier, dj.common.allowedTiers)}, ...
                dj.common.camelCase(tableInfo.className, true)];
            
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', self.schema.dbname, tableName);
            
            % add inherited primary key attrs
            primaryKeyFields = {};
            for iRef = 1:length(parents)
                for iField = find([parents{iRef}.table.attrs.iskey])
                    field = parents{iRef}.table.attrs(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        primaryKeyFields{end+1} = field.name;   %#ok<AGROW>
                        assert(~field.isnullable, 'primary key attrs cannot be nullable')
                        sql = sprintf('%s%s', sql, fieldToSQL(field));
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
                    sql = sprintf('%s%s', sql, fieldToSQL(field));
                end
            end
            
            % add secondary foreign key attrs
            for iRef = 1:length(references)
                for iField = find([references{iRef}.table.attrs.iskey])
                    field = references{iRef}.table.attrs(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        sql = sprintf('%s%s', sql, fieldToSQL(field));
                    end
                end
            end
            
            % add dependent attrs
            if ~isempty(fieldDefs)
                for iField = find(~[fieldDefs.iskey])
                    field = fieldDefs(iField);
                    sql = sprintf('%s%s', sql, fieldToSQL(field));
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
                query(dj.conn, sql);
            end
            self.schema.reload
        end
    end
end








%          LOCAL FUNCTIONS


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
        if ~any(strcmpi(field.default, dj.Table.mysql_constants)) && ...
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
    declaration = dj.common.str2cell(declaration);
end
assert(iscellstr(declaration), ...
    'declaration must be a multiline string or a cellstr');

% remove empty lines
declaration(cellfun(@(x) isempty(strtrim(x)), declaration)) = [];

% expand <<macros>>   TODO: make macro expansion recursive (if necessary)
for macro = fieldnames(dj.common.macros)'
    while true
        ix = find(strcmp(strtrim(declaration), ...
            ['<<' macro{1} '>>']),1,'first');
        if isempty(ix)
            break
        end
        declaration = [
            declaration(1:ix-1)
            dj.common.macros.(macro{1})
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
assert(ismember(tableInfo.tier, dj.common.allowedTiers),...
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
                fieldInfo = parseAttrDef(line, inKey);
                fieldDefs = [fieldDefs fieldInfo];  %#ok:<AGROW>
        end
    end
end
end



function fieldInfo = parseAttrDef(line, inKey)
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
end
