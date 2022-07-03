% dj.internal.Table provides the data definition interface to a single table in the
% database.
%
% Initialization:
%    table = dj.internal.Table('package.ClassName')
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
        schema          % handle to a schema object
    end
    
    properties(SetAccess = private)
        plainTableName  % just the table name
        tableHeader     % attribute information
    end
    
    properties(Dependent, SetAccess = private)
        info           % table information
        fullTableName  % `database`.`plain_table_name`
        ancestors      % names of all referenced tables, including self, recursively,
                       % in order of dependencies
        descendants    % names of all dependent tables, including self, recursively,
                       % in order of dependencies
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
                elseif isa(self,'dj.internal.ExternalTable')
                    store = self.store;
                    store(1) = upper(store(1));
                    name = [self.schema.package '.External' store];
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
                parts = strsplit(self.className, '.');
                for i=1:length(parts)-1
                    schemaFunction = strjoin([parts(1:i) {'getSchema'}], '.');
                    success = ~isempty(which(schemaFunction));
                    if success
                        break
                    end
                end
                assert(success, ['Could not find ' schemaFunction])
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
        
        
        function list = parents(self, varargin)
            self.schema.reload(false)
            list = self.schema.conn.parents(self.fullTableName, varargin{:});
        end
        
        
        function list = children(self, varargin)
            self.schema.reload(false)
            list = self.schema.conn.children(self.fullTableName, varargin{:});
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
                    cellfun(@(name) recurse(dj.Table(self.schema.conn.tableToClass(name)), ...
                        level+1), table.parents())
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
                    cellfun(@(name) recurse(dj.internal.Table( ...
                        self.schema.conn.tableToClass(name)),level+1), table.children())
                    map(table.className)=level;
                end
            end
        end
        
        
        function ret = sizeOnDisk(self)
            % return the table's size on disk in Mebibytes
            s = self.schema.conn.query(...
                sprintf('SHOW TABLE STATUS FROM `%s` WHERE name="%s"', self.schema.dbname, ...
                self.plainTableName), 'bigint_to_double');
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
                down = dj.config('displayDiagram_hierarchy_radius');
                down = down(2);
            end
            if nargin<=1
                up = dj.config('displayDiagram_hierarchy_radius');
                up = up(1);
            end
            
            d = dj.ERD(self);
            n = length(d.nodes);
            while down>0 || up>0
                if down>0
                    down = down - 1;
                    d.down
                end
                if up>0
                    up = up - 1;
                    d.up
                end
                if length(d.nodes)==n
                    break
                end
                n = length(d.nodes);
            end
            d.draw
        end
        
        
        function str = re(self)
            % alias for self.describe
            warning(['dj.Table/re is deprecated and will be removed in future releases: ' ...
                'Use dj.Table/describe instead']);
            str = self.describe;
        end
        
        
        function str = describe(self)
            % dj.Table/re - "reverse engineer" the table defintion.
            %
            % SYNTAX:
            %   str = table.describe
            %
            % str will contain the table definition string that can be used
            % to create the table using dj.Table.
            
            % table header
            str = sprintf('%%{\n# %s', self.info.comment);
            assert(any(strcmp(self.schema.classNames, self.className)), ...
                'class %s does not appear in the class list of the schema', self.className);
            
            % get foreign keys
            fk = self.schema.conn.foreignKeys;
            if ~isempty(fk)
                fk = fk(arrayfun(@(s) strcmp(s.from, self.fullTableName) && ...
                    ~contains(s.ref, '~external'), fk));
            end
            
            attributes_thus_far = {};
            inKey = true;
            for attr = self.tableHeader.attributes'
                if inKey && ~attr.iskey
                    str = sprintf('%s\n---', str);
                    inKey = false;
                end
                doInclude = ~any(arrayfun(@(x) ismember(attr.name, x.attrs), fk));
                attributes_thus_far{end+1} = attr.name; %#ok<AGROW>
                resolved = find(arrayfun(@(x) all(ismember(x.attrs, attributes_thus_far)),...
                    fk));
                for i = resolved
                    if isequal(fk(i).attrs, fk(i).ref_attrs)
                        str = sprintf('%s\n-> %s', str, ...
                            self.schema.conn.tableToClass(fk(i).ref));
                    else
                        ref_attr = setdiff(fk(i).attrs, fk(i).ref_attrs);
                        str = sprintf('%s\n (%s) -> %s', str, strjoin(ref_attr, ', '), ...
                                      self.schema.conn.tableToClass(fk(i).ref));
                    end
                end
                fk(resolved) = [];
                if doInclude
                    default = attr.default;
                    if attr.isnullable
                        default = '=null';
                    elseif ~isempty(default)
                        if attr.isNumeric || any(strcmp(default, ...
                                dj.internal.Declare.CONSTANT_LITERALS))
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
            end
            str = sprintf('%s\n%%}\n', str);
        end
        
        
        function optimize(self)
            % optimizes the table if it has become fragmented after repeated inserts and
            % deletes.
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
            
            [sql, ~, ~] = dj.internal.Declare.compileAttribute(...
                dj.internal.Declare.parseAttrDef(definition), []);
            self.alter(sprintf('ADD COLUMN %s%s', sql, after));
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
            [sql, ~, ~] = dj.internal.Declare.compileAttribute(...
                dj.internal.Declare.parseAttrDef(newDefinition), []);
            self.alter(sprintf('CHANGE COLUMN `%s` %s', attrName, sql));
        end
        
        function addForeignKey(self, target)
            % add a foreign key constraint.
            % The target must be a dj.Table object or a string with the
            % foreign key definition.
            % The referencing table must already possess all the attributes
            % of the primary key of the referenced table.
            %
            % EXAMPLE:
            %    tp.Align.table.addForeignKey(common.Scan)
            
            if isa(target, 'dj.Table')
                target = sprintf('->%s', target.className);
            end
            [attr_sql, fk_sql, ~, ~] = dj.internal.Declare.makeFK('', target, ...
                self.primaryKey, true, dj.internal.shorthash(self.fullTableName));
            self.alter(sprintf('ADD %s%s', attr_sql, fk_sql))
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
            allIndexes = self.getIndexes;
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
            allIndexes = self.getIndexes;
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
            
            % escape backslashes in pathname for proper display - only
            % relevant on Windows
            path = strrep(which(self.className), '\', '\\');
            if isempty(path)
                fprintf('File %s.m is not found\n', self.className);
            else
                if dj.config('safemode') ...
                        && ~strcmpi('yes', dj.internal.ask(sprintf(...
                        'Update the table definition and class definition in %s?',path)))
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
                    fprintf(f,'%s', self.describe);
                    lookup = struct(...
                        'lookup', 'dj.Lookup', ...
                        'manual', 'dj.Manual', ...
                        'imported', 'dj.Imported', ...
                        'computed', 'dj.Computed');
                    for i=p2+1:length(lines)
                        s = lines{i};
                        if ~isempty(regexp(s, '^\s*classdef', 'once'))
                            s = regexprep(s, 'dj\.Relvar\s*(&\s*dj\.AutoPopulate)?', ...
                                lookup.(self.info.tier));
                        end
                        fprintf(f,'%s\n', s);
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
            list = regexpi(self.tableHeader.attributes(ix).type, ...
                '^enum\((?<list>''.*'')\)$', 'names');
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
                fprintf 'ABOUT TO DROP TABLES: \n'
                tables = cellfun(@(x) dj.Relvar(x), self.descendants, 'uni', false);
                tables = [tables{:}];
                for table = tables
                    n = table.count;
                    fprintf('%20s (%s,%5d tuples)\n', table.fullTableName, table.info.tier, n)
                    doPrompt = doPrompt || n;   % prompt if not empty
                end
                
                % if any table has data, give option to cancel
                doPrompt = doPrompt && dj.config('safemode');  % suppress prompt
                if doPrompt && ~strcmpi('yes', dj.internal.ask('Proceed to drop?'))
                    disp 'User cancelled table drop'
                else
                    try
                        for table = tables(end:-1:1)
                            if isa(feval(table.className),'dj.Shared')
                                self.schema.conn.query(sprintf('DROP TABLE `%s`.`$%s`', ...
                                table.schema.dbname, table.plainTableName))
                            end
                            self.schema.conn.query(sprintf('DROP TABLE %s', ...
                                table.fullTableName))
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
        
    end
    
    
    methods
        
        function yes = isCreated(self)
            yes = self.schema.tableNames.isKey(self.className);
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
            def = dj.internal.Declare.getDefinition(self);

            [sql, external_stores] = dj.internal.Declare.declare(self, def);
            sql = strrep(sql, '{database}', self.schema.dbname);
            for k=1:length(external_stores)
                table = self.schema.external.table(external_stores{k});
                table.create;
            end
            self.schema.conn.query(sql);
            self.schema.reload;
            if isa(self,'dj.Shared')
                hiddenDef = ['%{',newline,'-> ',self.className,newline,'%}'];
                temp = dj.Hidden;
                temp.schema = self.schema;
                sql = dj.internal.Declare.declare(temp,hiddenDef);
                sql = strrep(sql,'`$hidden`',['`$',self.plainTableName,'`']);
                self.schema.conn.query(sql);

            end
            for parent = self.parents
                parentClassName = self.schema.conn.tableToClass(cell2mat(parent));
                if ~exist(parentClassName, 'class')
                    continue
                end
                parentClass = feval(parentClassName);
                if isa(parentClass,'dj.Shared')
                    
                    fk_i = strcmp(self.fullTableName,{self.schema.conn.foreignKeys(:).from}) & strcmp(parentClass.fullTableName,{self.schema.conn.foreignKeys(:).ref});
                    fk = self.schema.conn.foreignKeys(fk_i);
                    
                    if fk.primary
                        sql = sprintf('CREATE TRIGGER `%s`.`%s_shared_insert` BEFORE INSERT ON `%s`.`%s`',self.schema.dbname,self.plainTableName,self.schema.dbname,self.plainTableName);
                        sql = sprintf('%s%sFOR EACH ROW',sql,newline);
                        sql = sprintf('%s%sBEGIN',sql,newline);
                        sql = sprintf('%s%sINSERT INTO `%s`.`$%s` (%s)',sql,newline,parentClass.schema.dbname,parentClass.plainTableName,strjoin(fk.ref_attrs,','));
                        sql = sprintf('%s%sVALUES (%s);',sql,' ',strjoin(strcat('NEW.',fk.attrs),','));
                        sql = sprintf('%s%sEND',sql,newline);
                        self.schema.conn.query(sql);
                    end
                end
            end
        end
    end
    
    
    methods
        function indexInfo = getIndexes(self)
            % dj.Table/getIndexes
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
    end
end