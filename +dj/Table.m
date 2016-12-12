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
% https://github.com/datajoint/datajoint-matlab/wiki/Table-declaration

classdef Table < handle
    
    properties(SetAccess = protected)
        className    % the name of the corresponding base dj.Relvar class
    end
    
    properties(SetAccess = private)
        schema          % handle to a schema object
        plainTableName  % just the table name
        tableHeader     % attribute information
    end
    
    properties(Dependent, SetAccess = private)
        info           % table information
        fullTableName  % `database`.`plain_table_name`
        parents        % names of tables referenced by foreign keys composed exclusively of primary key attributes
        referenced     % names of tables referenced by foreign keys composed of primary and non-primary attributes
        children       % names of tables referencing this table with their primary key attributes
        referencing    % names of tables referencing this table with their primary and non-primary attributes
        ancestors      % names of all referenced tables, including self, recursively, in order of dependencies
        descendants    % names of all dependent tables, including self, recursively, in order of dependencies
    end
    
    properties(Constant)
        mysql_constants = {'CURRENT_TIMESTAMP'}
    end
    
    properties(Access=private)
        definition     % table definition
    end
    
    methods
        function self = Table(className)
            % dj.Table with no arguments is used when dj.Table is inherited by dj.Relvar
            % dj.Table('package.ClassName')  -  initialize with class name.
            if nargin>=1
                self.className = className;
            end
        end
        
        
        function name = get.className(self)
            name = self.className;
            if isempty(name)
                name = class(self);
                if any(strcmp(name,{'dj.Table','dj.Relvar'}))
                    name = '';
                end
            end
        end
        
        
        function set.className(self, className)
            self.className = className;
            assert(ischar(self.className) && ~isempty(self.className),  ...
                'dj.Table requres input ''package.ClassName''')
            assert(~isempty(regexp(self.className,'^\w+\.[A-Z]\w*','once')), ...
                'invalid table identification ''%s''. Should be package.ClassName', ...
                self.className)
        end
        
        
        function info = get.info(self)
            info = self.schema.headers(self.plainTableName).info;
        end
        
        
        function hdrObj = get.tableHeader(self)
            if isempty(self.tableHeader)
                self.tableHeader = self.schema.headers(self.plainTableName);
            end
            hdrObj = self.tableHeader;
        end
        
        
        function ret = get.schema(self)
            if isempty(self.schema)
                assert(~isempty(self.className), 'className not set')
                schemaFunction = regexprep(self.className, '\.\w+$', '.getSchema');
                assert(~isempty(which(schemaFunction)), ['Could not find ' schemaFunction])
                self.schema = feval(schemaFunction);
                assert(isa(self.schema, 'dj.Schema'), ...
                    [schemaFunction ' must return an instance of dj.Schema'])
            end
            ret = self.schema;
        end
        
        
        function name = get.fullTableName(self)
            name = sprintf('`%s`.`%s`', self.schema.dbname, self.plainTableName);
        end
        
        
        function name = get.plainTableName(self)
            if isempty(self.plainTableName)
                self.create
                self.plainTableName = self.schema.tableNames(self.className);
            end
            name = self.plainTableName;
        end
        
        
        function list = get.parents(self)
            self.schema.reload(false)
            list = self.schema.conn.parents(self.fullTableName);
        end
        
        
        function list = get.referenced(self)
            self.schema.reload(false)
            list = self.schema.conn.referenced(self.fullTableName);
        end
        
        
        function list = get.children(self)
            self.schema.reload(false)
            list = self.schema.conn.children(self.fullTableName);
        end
        
        
        function list = get.referencing(self)
            self.schema.reload(false)
            list = self.schema.conn.referencing(self.fullTableName);
        end
        
        
        function list = get.ancestors(self)
            map = containers.Map('KeyType','char','ValueType','uint16');
            recurse(self,0)
            levels = map.values;
            [~,order] = sort([levels{:}],'descend');
            list = map.keys;
            list = list(order);
            
            function recurse(table,level)
                if ~map.isKey(table.className) || level>map(table.className)
                    cellfun(@(name) recurse(dj.Table(self.schema.conn.tableToClass(name)),level+1), ...
                        [table.parents table.referenced])
                    map(table.className)=level;
                end
            end
        end
        
        
        
        function list = get.descendants(self)
            map = containers.Map('KeyType','char','ValueType','uint16');
            recurse(self,0)
            levels = map.values;
            [~,order] = sort([levels{:}]);
            list = map.keys;
            list = list(order);
            
            function recurse(table,level)
                if ~map.isKey(table.className) || level>map(table.className)
                    cellfun(@(name) recurse(dj.Table(self.schema.conn.tableToClass(name)),level+1), ...
                        [table.children table.referencing])
                    map(table.className)=level;
                end
            end
        end
        
        
        
        function ret = sizeOnDisk(self)
            % return the table's size on disk in Mebibytes
            s = self.schema.conn.query(...
                sprintf('SHOW TABLE STATUS FROM `%s` WHERE name="%s"', self.schema.dbname, self.plainTableName),...
                'bigint_to_double');
            tableSize = (s.Data_length + s.Index_length)/1024/1024;
            if nargout
                ret = tableSize;
            else
                fprintf('Size on disk %u MB\n', ceil(tableSize))
            end
        end
        
        
        
        function erd(self, up, down)
            % dj.Table/erd - plot the entity relationship diagram of tables
            % that are connected to self.
            %
            % SYNTAX
            %   table.erd(up, down)
            %   table.erd  -- equivalent to table.erd(2,2)
            %
            % See also dj.Schema/erd
            
            self.create
            if nargin<=2
                down = dj.set('tableErdRadius');
                down = down(2);
            end
            if nargin<=1
                up = dj.set('tableErdRadius');
                up = up(1);
            end
            
            self.schema.conn.erd({self.fullTableName},up,down)
        end
        
        
        function str = re(self)
            % dj.Table/re - "reverse engineer" the table defintion.
            %
            % SYNTAX:
            %   str = table.re
            %
            % str will contain the table definition string that can be used
            % to create the table using dj.Table.
            
            str = sprintf('%%{\n%s (%s) # %s', ...
                self.className, self.info.tier, self.info.comment);
            assert(any(strcmp(self.schema.classNames, self.className)), ...
                'class %s does not appear in the class list of the schema', self.className);
            
            % list primary key fields
            keyFields = self.tableHeader.primaryKey;
            
            % list parent referenced
            [classNames,tables] = self.sortForeignKeys(self.parents);
            if ~isempty(classNames)
                str = sprintf('%s%s',str,sprintf('\n-> %s',classNames{:}));
                for t = tables
                    % exclude primary key fields of referenced tables from the primary attribute list
                    keyFields = keyFields(~ismember(keyFields, t.tableHeader.primaryKey));
                end
            end
            
            % additional primary attributes
            for i=find(ismember(self.tableHeader.names, keyFields))
                comment = self.tableHeader.attributes(i).comment;
                if self.tableHeader.attributes(i).isautoincrement
                    autoIncrement = 'AUTO_INCREMENT';
                else
                    autoIncrement = '';
                end
                str = sprintf('%s\n%-40s # %s', str, ...
                    sprintf('%-16s: %s %s', self.tableHeader.attributes(i).name, ...
                    self.tableHeader.attributes(i).type, autoIncrement), comment);
            end
            
            % dividing line
            str = sprintf('%s\n---', str);
            
            % list dependent attributes
            dependentFields = self.tableHeader.dependentFields;
            
            % list other referenced
            [classNames,tables] = self.sortForeignKeys(self.referenced);
            if ~isempty(classNames)
                str = sprintf('%s%s',str,sprintf('\n-> %s',classNames{:}));
                for t = tables
                    % exclude primary key fields of referenced tables from header
                    dependentFields = dependentFields(~ismember(dependentFields, t.tableHeader.primaryKey));
                end
            end
            
            % list remaining attributes
            for i=find(ismember(self.tableHeader.names, dependentFields))
                attr = self.tableHeader.attributes(i);
                default = attr.default;
                if attr.isnullable
                    default = '=null';
                elseif ~isempty(default)
                    if attr.isNumeric || any(strcmp(default,self.mysql_constants))
                        default = ['=' default]; %#ok<AGROW>
                    else
                        default = ['="' default '"']; %#ok<AGROW>
                    end
                end
                if attr.isautoincrement
                    autoIncrement = 'AUTO_INCREMENT';
                else
                    autoIncrement = '';
                end
                str = sprintf('%s\n%-60s# %s', str, ...
                    sprintf('%-28s: %s', [attr.name default], ...
                    [attr.type ' ' autoIncrement]), attr.comment);
            end
            str = sprintf('%s\n', str);
            
            % list user-defined secondary indexes
            allIndexes = self.getDatabaseIndexes;
            implicitIndexes = self.getImplicitIndexes;
            for thisIndex=allIndexes
                % Skip implicit indexes
                if ~any(arrayfun( ...
                        @(x) isequal(x.attributes, thisIndex.attributes), ...
                        implicitIndexes))
                    attributeList = sprintf('%s,', thisIndex.attributes{:});
                    if thisIndex.unique
                        modifier = 'UNIQUE ';
                    else
                        modifier = '';
                    end
                    str = sprintf('%s%sINDEX(%s)\n', str, modifier, attributeList(1:end-1));
                end
            end
            
            str = sprintf('%s%%}\n', str);
        end
        
        
        function optimize(self)
            % optimizes the table if it has become fragmented after repeated inserts and deletes.
            % See http://dev.mysql.com/doc/refman/5.6/en/optimize-table.html
            fprintf 'optimizing ...'
            status = self.schema.conn.query(...
                sprintf('OPTIMIZE LOCAL TABLE %s', self.fullTableName));
            disp(status.Msg_text{end})
        end
        
        
        %%%%% ALTER METHODS: change table definitions %%%%%%%%%%%%
        function setTableComment(self, newComment)
            % dj.Table/setTableComment - update the table comment
            % in the table definition
            self.alter(sprintf('COMMENT="%s"', newComment));
        end
        
        function addAttribute(self, definition, after)
            % dj.Table/addAttribute - add a new attribute to the
            % table. A full line from the table definition is
            % passed in as "definition".
            %
            % The definition can specify where to place the new attribute.
            % Make after="FIRST" to add the attribute as the first
            % attribute or "AFTER `attr`" to place it after an existing
            % attribute.
            if nargin<3
                after='';
            else
                assert(strcmpi(after,'FIRST') || strncmpi(after,'AFTER',5))
                after = [' ' after];
            end
            
            sql = fieldToSQL(parseAttrDef(definition));
            self.alter(sprintf('ADD COLUMN %s%s', sql(1:end-2), after));
        end
        
        function dropAttribute(self, attrName)
            % dj.Table/dropAttribute - drop the attribute attrName
            % from the table definition
            self.alter(sprintf('DROP COLUMN `%s`', attrName));
        end
        
        function alterAttribute(self, attrName, newDefinition)
            % dj.Table/alterAttribute - Modify the definition of attribute
            % attrName using its new line from the table definition
            % "newDefinition"
            sql = fieldToSQL(parseAttrDef(newDefinition));
            self.alter(sprintf('CHANGE COLUMN `%s` %s', attrName, sql(1:end-2)));
        end
        
        function addForeignKey(self, target)
            % add a foreign key constraint.
            % The target must be a dj.Relvar object.
            % The referencing table must already possess all the attributes
            % of the primary key of the referenced table.
            %
            % EXAMPLE:
            %    tp.Align.table.addForeignKey(common.Scan)
            
            fieldList = sprintf('%s,', target.primaryKey{:});
            fieldList(end)=[];  % drop trailing comma
            self.alter( sprintf(...
                ['ADD FOREIGN KEY (%s) REFERENCES %s (%s) ' ...
                'ON UPDATE CASCADE ON DELETE RESTRICT\n'], ...
                fieldList, target.fullTableName, fieldList));
        end
        
        function dropForeignKey(self, target)
            % drop a foreign key constraint.
            % The target must be a dj.Relvar object.
            
            % get constraint name
            sql = sprintf( ...
                ['SELECT distinct constraint_name AS name ' ...
                'FROM information_schema.key_column_usage ' ...
                'WHERE table_schema="%s" and table_name="%s"' ...
                'AND referenced_table_schema="%s" ' ...
                'AND referenced_table_name="%s"'], ...
                self.schema.dbname, self.plainTableName, ...
                target.schema.dbname, target.plainTableName);
            name = self.schema.conn.query(sql);
            if isempty(name.name)
                disp 'No matching foreign key'
            else
                self.alter(sprintf('DROP FOREIGN KEY `%s`', name.name{1}));
            end
        end
        
        function addIndex(self, isUniqueIndex, indexAttributes)
            % dj.Table/addIndex - add a new secondary index to the
            % table.
            % isUniqueIndex - Set true to add a unique index
            % indexAttributes - cell array of attribute names to be indexed
            if ischar(indexAttributes)
                indexAttributes = {indexAttributes};
            end
            assert(~isempty(indexAttributes) && ...
                all(ismember(indexAttributes, {self.tableHeader.name})), ...
                'Index definition contains invalid attribute names');
            % Don't allow indexes that may conflict with foreign keys
            implicitIndexes = self.getImplicitIndexes;
            assert( ~any(arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), ...
                implicitIndexes)), ...
                ['The specified set of attributes is implicitly ' ...
                'indexed because of a foreign key constraint.']);
            % Prevent interference with existing indexes
            allIndexes = self.getDatabaseIndexes;
            assert( ~any(arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), ...
                allIndexes)), ...
                ['Only one index can be specified for any tuple ' ...
                'of attributes. To change the index type, drop ' ...
                'the existing index first.']);
            % Create a new index
            fieldList = sprintf('`%s`,', indexAttributes{:});
            if isUniqueIndex
                modifier = 'UNIQUE ';
            else
                modifier = '';
            end
            self.alter(sprintf('ADD %sINDEX (%s)', modifier, fieldList(1:end-1)));
        end
        
        function dropIndex(self, indexAttributes)
            % dj.Table/dropIndex - Drops a secondary index from the
            % table.
            % indexAttributes - cell array of attribute names that define
            %                   the index. The order of attributes
            %                   matters!
            if ischar(indexAttributes)
                indexAttributes = {indexAttributes};
            end
            
            % Don't touch indexes introduced by foreign keys
            implicitIndexes = self.getImplicitIndexes;
            assert(~any(arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), ...
                implicitIndexes)), ...
                ['The specified set of attributes is indexed ' ...
                'because of a foreign key constraint. This index ' ...
                'cannot be dropped.']);
            
            % Drop specified index(es). There should only be one unless
            % they were redundantly created outside of DataJoint.
            allIndexes = self.getDatabaseIndexes;
            selIndexToDrop = arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), allIndexes);
            if any(selIndexToDrop)
                arrayfun(@(x) self.alter(sprintf('DROP INDEX `%s`', x.name)), ...
                    allIndexes(selIndexToDrop));
            else
                error('Could not locate specified index in database.')
            end
        end
        
        function syncDef(self)
            % dj.Table/syncDef replace the table definition in the file
            % <package>.<className>.m with the actual definition from the database.
            %
            % This method is useful if the table definition has been
            % changed by other means than the regular datajoint definition
            % process.
            path = which(self.className);
            if isempty(path)
                fprintf('File %s.m is not found\n', self.className);
            else
                if ~dj.set('suppressPrompt') ...
                        && ~strcmpi('yes', dj.ask(sprintf('Update table definition in %s?',path)))
                    disp 'No? Table definition left untouched.'
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
        
        function list = getEnumValues(self, attr)
            % returns the list of allowed values for the attribute attr of type enum
            ix = strcmpi(attr, self.tableHeader.names);
            assert(any(ix), 'Attribute "%s" not found', attr)
            list = regexpi(self.tableHeader.attributes(ix).type,'^enum\((?<list>''.*'')\)$', 'names');
            assert(~isempty(list), 'Attribute "%s" not of type ENUM', attr)
            list = regexp(list.list,'''(?<item>[^'']+)''','names');
            list = {list.item};
        end
        
        %%%%%  END ALTER METHODS
        
        
        
        function drop(self)
            % dj.Table/drop - drop the table and all its dependents.
            % Confirmation is requested if the dropped tables contain data.
            %
            % Although drop reloads the schema information upon completion,
            % "clear classes" may be necessary to remove constant object
            % properties and persistent variables that refer to the dropped
            % table.
            %
            % See also dj.Table, dj.BaseRelvar/del
            
            if ~self.isCreated
                disp 'Nothing to drop'
            else
                doPrompt = false;  % don't prompt if tables are empty
                self.schema.conn.cancelTransaction   % exit ongoing transaction
                % warn user if self is a subtable
                if ismember(self.info.tier, {'imported','computed'}) && ...
                        ~isempty(which(self.className))
                    rel = eval(self.className);
                    if ~isa(rel,'dj.AutoPopulate') && ~dj.set('suppressPrompt')
                        fprintf(['\n!!! %s is a subtable. For referential integrity, ' ...
                            'drop its parent table instead.\n'], self.className)
                        if ~strcmpi('yes', dj.ask('Proceed anyway?'))
                            fprintf '\ndrop cancelled\n\n'
                            return
                        end
                    end
                end
                fprintf 'ABOUT TO DROP TABLES: \n'
                tables = cellfun(@(x) dj.Relvar(x), self.descendants, 'uni', false);
                tables = [tables{:}];
                for table = tables
                    n = table.count;
                    fprintf('%20s (%s,%5d tuples)\n', table.fullTableName, table.info.tier, n)
                    doPrompt = doPrompt || n;   % prompt if not empty
                end
                
                % if any table has data, give option to cancel
                doPrompt = doPrompt && ~dj.set('suppressPrompt');  % suppress prompt
                if doPrompt && ~strcmpi('yes', dj.ask('Proceed to drop?'))
                    disp 'User cancelled table drop'
                else
                    try
                        for table = tables(end:-1:1)
                            self.schema.conn.query(sprintf('DROP TABLE %s', table.fullTableName))
                            fprintf('Dropped table %s\n', table.fullTableName)
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
    end
    
    methods(Access=private)
        
        function yes = isCreated(self)
            yes = self.schema.tableNames.isKey(self.className);
        end
        
        
        function definition = getDefinition(self)
            % extract the table declaration with the first percent-brace comment
            % block of the matching .m file.
            if ~isempty(self.definition)
                definition = self.definition;
            else
                file = which(self.className);
                assert(~isempty(file), ...
                    'MissingTableDefinition:Could not find table definition file %s', self.className)
                definition = readPercentBraceComment(file);
                assert(~isempty(definition), ...
                    'MissingTableDefnition:Could not find the table declaration in %s', file)
            end
        end
        
        
        
        function create(self)
            % parses the table declration and declares the table
  
            if self.isCreated
                return
            end
            self.schema.reload   % ensure that the table does not already exist
            if self.isCreated
                return
            end
            def = self.getDefinition();
            
            % split into a columnwise cell array
            def = strtrim(regexp(def,'\n','split')');
            
            % append the next line to lines that end in a backslash
            for i=find(cellfun(@(x) ~isempty(x) && x(end)=='\', def'))
                def{i} = [def{i}(1:end-1) ' ' def{i+1}];
                def(i+1) = '';
            end

            % remove empty lines and comment lines
            def(cellfun(@(x) isempty(strtrim(x)) || strncmp('#',strtrim(x),1), def)) = [];

            % parse table schema, name, type, and comment
            pat = {
                '^(?<package>\w+)\.(?<className>\w+)\s*'  % package.TableName
                '\(\s*(?<tier>\w+)\s*\)\s*'               % (tier)
                '#\s*(?<comment>.*)$'                     % # comment
                };
            tableInfo = regexp(def{1}, cat(2,pat{:}), 'names');
            assert(numel(tableInfo)==1, ...
                'invalidTableDeclaration:Incorrect syntax in table declaration, line 1')
            assert(ismember(tableInfo.tier, dj.Schema.allowedTiers),...
                'invalidTableTier:Invalid tier for table ', tableInfo.className)
            cname = sprintf('%s.%s', tableInfo.package, tableInfo.className);
            assert(strcmp(cname, self.className), ...
                'Table name %s does not match in file %s', cname, self.className)
                
            % CREATE TABLE
            tableName = [self.schema.prefix, ...
                dj.Schema.tierPrefixes{strcmp(tableInfo.tier, dj.Schema.allowedTiers)}, ...
                dj.fromCamelCase(tableInfo.className)];
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', self.schema.dbname, tableName);
            
            % fields and foreign keys
            inKey = true;
            primaryFields = {};
            fields = {};
            for iLine = 2:length(def)
                line = def{iLine};
                switch true
                    case strncmp(line,'---',3)
                        inKey = false;
                        
                        % foreign key
                    case regexp(line, '^(\s*\([^)]+\)\s*)?->.*')
                        line = strtrim(strtok(line, '#'));
                        parts = strsplit(line, '->');
                        [attrs, cname] = deal(parts{:});
                        rel = dj.Relvar(strtrim(cname));
                        assert(isa(rel, 'dj.Relvar'), 'foreign keys must be base relvars')
                        [sql, newFields] = makeFK(sql, strtrim(attrs), rel, fields, inKey);
                        fields = [fields, newFields]; %#ok<AGROW>
                        if inKey
                            primaryFields = [primaryFields, newFields]; %#ok<AGROW>
                        end
                        
                        % index
                    case regexpi(line, '^(unique\s+)?index[^:]*$')
                        sql = sprintf('%s%s,\n', sql, line);    %  add checks
                        
                        % attribute
                    case regexp(line, ['^[a-z][a-z\d_]*\s*' ...       % name
                            '(=\s*\S+(\s+\S+)*\s*)?' ...              % opt. default
                            ':\s*\w.*$'])                             % type, comment
                        fieldInfo = parseAttrDef(line);
                        assert(~inKey || ~fieldInfo.isnullable, ...
                            'primary key attributes cannot be nullable')
                        if inKey
                            primaryFields{end+1} = fieldInfo.name; %#ok<AGROW>
                        end
                        fields{end+1} = fieldInfo.name; %#ok<AGROW>
                        sql = sprintf('%s%s', sql, fieldToSQL(fieldInfo));   
                        
                    otherwise
                        error('Invalid table declaration line "%s"', line)
                end
            end
            
            % add primary key declaration
            assert(~isempty(primaryFields), 'table must have a primary key')
            sql = sprintf('%sPRIMARY KEY (%s),\n' ,sql, backquotedList(primaryFields));
            
            % finish the declaration
            sql = sprintf('%s\n) ENGINE = InnoDB, COMMENT "%s"', sql(1:end-2), tableInfo.comment);
            
            % execute declaration
            fprintf \n<SQL>\n
            fprintf(sql)
            fprintf \n</SQL>\n\n
            self.schema.conn.query(sql);
            self.schema.reload
        end


        
        function alter(self, alterStatement)
            % dj.Table/alter
            % alter(self, alterStatement)
            % Executes an ALTER TABLE statement for this table.
            % The schema is reloaded and syncDef is called.
            sql = sprintf('ALTER TABLE  %s %s', ...
                self.fullTableName, alterStatement);
            self.schema.conn.query(sql);
            disp 'table updated'
            self.schema.reload
            self.tableHeader = [];          % Force update of cached header
            self.syncDef
        end
        
        function indexInfo = getDatabaseIndexes(self)
            % dj.Table/getDatabaseIndexes
            % Returns all secondary database indexes,
            % as given by the "SHOW INDEX" query
            indexInfo = struct('attributes', {}, ...
                'unique', {}, 'name', {});
            indexes = dj.struct.fromFields( ...
                self.schema.conn.query(sprintf(...
                ['SHOW INDEX FROM `%s` IN `%s` ' ...
                'WHERE NOT `Key_name`="PRIMARY"'], ...
                self.plainTableName, self.schema.dbname),'bigint_to_double'));
            [indexNames, ~, indexId] = unique({indexes.Key_name});
            for iIndex=1:numel(indexNames)
                % Get attribute names and sort by position in index
                thisIndex = indexes(indexId == iIndex);
                [~, sortPerm] = sort([thisIndex.Seq_in_index]);
                thisIndex = thisIndex(sortPerm);
                indexInfo(end+1).attributes = {thisIndex.Column_name};  %#ok<AGROW>
                indexInfo(end).unique = ~thisIndex(1).Non_unique;
                indexInfo(end).name = indexNames{iIndex};
            end
        end
        
        
        function indexInfo = getImplicitIndexes(self)
            % dj.Table/getImplicitIndexes
            % Returns database indexes that are implied by
            % table relationships and should not be shown to the user
            % or modified by the user
            indexInfo = struct('attributes', {}, 'unique', {});
            for refTable = [self.referenced self.parents]
                refObj = dj.Table(self.schema.conn.tableToClass(refTable{1},true));
                indexInfo(end+1).attributes = refObj.tableHeader.primaryKey;  %#ok<AGROW>
            end
        end
        
        
        
        function [classNames,tables] = sortForeignKeys(self, tableNames)
            % sort referenced tables so that they reproduce the correct
            % order of primary key attributes
            tables = cellfun(@(x) dj.Table(self.schema.conn.tableToClass(x,true)), tableNames, 'uni', false);
            tables = [tables{:}];
            if isempty(tables)
                classNames = {};
            else
                fkFields = arrayfun(@(x) {x.tableHeader.attributes([x.tableHeader.attributes.iskey]).name}, tables,'uni',false);
                fkOrder = cellfun(@(s) cellfun(@(x) find(strcmp(x,{self.tableHeader.attributes.name})), s), fkFields, 'uni', false);
                m = max(cellfun(@max, fkOrder));
                [~,fkOrder] = sort(cellfun(@(x) sum((x-1).*m.^-(1:length(x))), fkOrder));
                tables = tables(fkOrder);
                classNames ={tables.className};
            end
        end
    end
end


%          LOCAL FUNCTIONS

function str = readPercentBraceComment(filename)
% reads the initial comment block %{ ... %} in filename

f = fopen(filename, 'rt');
assert(f~=-1, 'Could not open %s', filename)
str = '';

% skip all lines that do not begin with a %{
l = fgetl(f);
while ischar(l) && ~strcmp(strtrim(l),'%{')
    l = fgetl(f);
end

% read the contents of the comment
if ischar(l)
    while true
        l = fgetl(f);
        if strcmp(strtrim(l),'%}')
            break
        end
        str = sprintf('%s%s\n', str, l);
    end
end

fclose(f);
end



function sql = fieldToSQL(field)
% convert the structure field with header {'name' 'type' 'default' 'comment'}
% to the SQL column declaration

if field.isnullable   % all nullable attributes default to null
    default = 'DEFAULT NULL';
else
    default = 'NOT NULL';
    if ~isempty(field.default)
        % enclose value in quotes (even numeric), except special SQL values
        % or values already enclosed by the user
        if any(strcmpi(field.default, dj.Table.mysql_constants)) || ...
                ismember(field.default(1), {'''', '"'})
            default = sprintf('%s DEFAULT %s', default, field.default);
        else
            default = sprintf('%s DEFAULT "%s"', default, field.default);
        end
    end
end
assert(~any(ismember(field.comment, '"\')), ... % TODO: escape isntead
    'illegal characters in attribute comment "%s"', field.comment)
sql = sprintf('`%s` %s %s COMMENT "%s",\n', ...
    field.name, field.type, default, field.comment);
end


function [sql, newFields] = makeFK(sql, attrs, rel, existingFields, inKey)
% add foreign key to SQL table definition
newFields = {};
toFields = rel.primaryKey;    % referenced fields
if isempty(attrs)
    fromFields = toFields;
else
    fromFields = [toFields(ismember(toFields, existingFields)) ...
        cellfun(@strtrim, strsplit(attrs(2:end-1), ','), 'uni', false)];
    assert(length(fromFields)==length(toFields), ...
        'invalid reference %s -> %s', attrs, rel.className)
end
% fromFields and toFields are sorted in the same order as ref.rel.tableHeader.attributes
for i = 1:length(fromFields)
    if ~ismember(fromFields(i), existingFields)
        newFields(end+1) = fromFields(i); %#ok<AGROW>
        fieldInfo = rel.tableHeader.attributes(i);
        fieldInfo.name = fromFields{i};
        fieldInfo.nullabe = ~inKey;   % nonprimary references are nullable
        sql = sprintf('%s%s', sql, fieldToSQL(fieldInfo));
    end
end
sql = sprintf(...
    '%sFOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE CASCADE ON DELETE RESTRICT,\n', ...
    sql, backquotedList(fromFields), rel.fullTableName, backquotedList(toFields));
end


function fieldInfo = parseAttrDef(line)
line = strtrim(line);
pat = {
    '^(?<name>[a-z][a-z\d_]*)\s*'     % field name
    '=\s*(?<default>\S+(\s+\S+)*)\s*' % default value
    ':\s*(?<type>\w[^#]*\S)\s*'       % datatype
    '#\s*'                            % comment delimiter
    '(?<comment>\S.*\S)\s*'           % comment
    '$'                               % line end
    };
for sub = {[1 2 3 4 5 6] [1 3 4 5 6] [1 2 3 4 6] [1 2 3 6] [1 3 4 6] [1 3 6]}
    fieldInfo = regexp(line, cat(2,pat{sub{:}}), 'names');
    if ~isempty(fieldInfo)
        break
    end
end
assert(numel(fieldInfo)==1, 'Invalid field declaration "%s"', line)
if ~isfield(fieldInfo,'comment')
    fieldInfo.comment = '';
end
if ~isfield(fieldInfo,'default')
    fieldInfo.default = '';
end
assert(isempty(regexp(fieldInfo.type,'^bigint', 'once')) ...
    || ~strcmp(fieldInfo.default,'null'), ...
    'BIGINT attributes cannot be nullable in "%s"', line)
fieldInfo.isnullable = strcmpi(fieldInfo.default,'null');
end



function str = backquotedList(arr)
    str = sprintf('`%s`,', arr{:});
    str(end)=[];
end
