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

classdef Table < handle
    
    properties(SetAccess = protected)
        className    % the name of the corresponding base dj.Relvar class
    end
    
    properties(SetAccess = private)
        schema          % handle to a schema object
        plainTableName  % just the table name
    end
    
    properties(Dependent, SetAccess = private)
        fullTableName  % `database`.`plain_table_name`
        tableHeader    % attribute information
        parents        % names of tables referenced by foregin keys composed exclusively of primary key attributes
        references     % names of tables referenced by foreign keys composed of primary and non-primary attributes
        children       % names of tables referencing this table with their primary key attributes
        referencing    % names of tables referencing this table with their primary and non-primary attributes
        descendants    % names of all dependent tables, including self, recursively, in order of dependencies
    end
    
    properties(Constant,Access=private)
        mysql_constants = {'CURRENT_TIMESTAMP'}
    end
    
    properties(Access=private)
        declaration     % table declaration
    end    
    
    methods
        function self = Table(className)
            if nargin>=1
                self.className = className;
            end
        end
        
        
        function name = get.className(self)
            name = self.className;
            if isempty(name)
                name = class(self);
                assert(isa(self,'dj.Relvar') && ~strcmp(name,'dj.Relvar'))   %#ok<STISA>
                self.className = name;
            end
        end
        
        
        function set.className(self, className)
            self.className = className;
            dj.assert(ischar(self.className) && ~isempty(self.className),  ...
                'dj.Table requres input ''package.ClassName''')
            dj.assert(self.className(1)~='$', ...
                'Please activate package for %s', self.className)
            dj.assert(~isempty(regexp(self.className,'^\w+\.[A-Z]\w*','once')), ...
                'invalid table identification ''%s''. Should be package.ClassName', ...
                self.className)
        end
        
        
        function hdrObj = get.tableHeader(self)
            hdrObj = self.schema.headers(self.plainTableName);
        end
        
        
        function ret = get.schema(self)
            if isempty(self.schema)
                dj.assert(~isempty(self.className), 'className not set')
                schemaFunction = regexprep(self.className, '\.\w+$', '.getSchema');
                dj.assert(~isempty(which(schemaFunction)), ['Could not find ' schemaFunction])
                self.schema = feval(schemaFunction);
                dj.assert(isa(self.schema, 'dj.Schema'), ...
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
            list = self.schema.classNames(self.schema.dependencies(strcmp(self.className, self.schema.classNames),:)==1);
            list = cellfun(@(name) self.schema.conn.getPackage(name), list, 'uniformOutput', false);
        end
        
        
        function list = get.references(self)
            list = self.schema.classNames(self.schema.dependencies(strcmp(self.className, self.schema.classNames),:)==2);
            list = cellfun(@(name) self.schema.conn.getPackage(name), list, 'uniformOutput', false);
        end
        
        
        function list = get.children(self)
            list = self.schema.classNames(self.schema.dependencies(:,strcmp(self.className, self.schema.classNames))==1);
            list = cellfun(@(name) self.schema.conn.getPackage(name), list, 'uniformOutput', false);
        end
        
        
        function list = get.referencing(self)
            list = self.schema.classNames(self.schema.dependencies(:,strcmp(self.className, self.schema.classNames))==2);
            list = cellfun(@(name) self.schema.conn.getPackage(name), list, 'uniformOutput', false);
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
                    cellfun(@(name) recurse(dj.Table(name),level+1), ...
                        [table.children table.referencing])
                    map(table.className)=level;
                end
            end
        end
        
        
        
        function showTable(self)
            fprintf \n
            for i=1:numel(self)
                fprintf('DataJoint table\n\n')
                disp(self(i).re(true))
                s = self(i).schema.conn.query(sprintf([...
                    'SELECT (data_length+index_length)/1024/1024 table_size_mb ' ...
                    'FROM information_schema.tables WHERE table_schema="%s" and table_name="%s"'],...
                    self(i).schema.dbname, self(i).plainTableName));
            end
            fprintf('Size on disk %u MB\n', ceil(s.table_size_mb));
            fprintf('\n<a href="matlab:disp(%s.table.re)">Display declaration</a>. <a href="matlab:%s.table.erd">Plot ERD</a>\n\n',...
                self.className, self.className)
        end
        
        
        
        function erd(self, depth1, depth2)
            % dj.Table/erd - plot the entity relationship diagram of tables
            % that are connected to self.
            %
            % SYNTAX
            %   table.erd([depth1,depth2]])
            %
            % depth1 and depth2 specify the connectivity radius upstream
            % (depth<0) and downstream (depth>0) of this table.
            % Omitting both depths defaults to table.erd(-2,2).
            % Omitting any one of the depths sets it to zero.
            %
            % Examples:
            %   t = dj.Table('vis2p.Scans');
            %   t.erd(-1,1)  % plot immediate ancestors and descendants
            %   t.erd(-1,0)  % plot only immediate ancestors
            %   t.erd(-2,2)  % plot two levels in each direction
            %   t.erd    -- same as t.erd(-2,2)
            %
            % See also dj.Schema/erd
            self.create
            if nargin<=1
                depth1 = -2;
                depth2 = +2;
            end
            dj.assert(depth1<=0 && depth2>=0);
            subset = {self.className};
            tabs = self;
            for i=1:max(-depth1,depth2)
                newTabs = {};
                for tab = tabs
                    new = [];
                    if i<=-depth1
                        new = [new tab.parents tab.references]; %#ok<AGROW>
                    end
                    if i<=depth2
                        new = [new tab.children tab.referencing]; %#ok<AGROW>
                    end
                    subset = union(subset, new);
                    new = new(cellfun(@(x) x(1)~='$',new)); % do not expand unloaded schemas
                    newTabs = [newTabs cellfun(@(x) dj.Table(x), new, 'UniformOutput', false)]; %#ok<AGROW>
                end
                tabs = [newTabs{:}];
            end
            self.schema.erd(subset)
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
            % When the second input expandForeignKeys is false, references
            % to other tables are not displayed and foreign key attributes
            % are shown as regular attributes.
            %
            % See also dj.Table
            
            expandForeignKeys = nargin>=2 && expandForeignKeys;
            
            str = '';
            if ~expandForeignKeys
                str = sprintf('%%{\n');
            end
            str = sprintf('%s%s (%s) # %s', ...
                str, self.className, self.info.tier, self.info.comment);
            dj.assert(any(strcmp(self.schema.classNames, self.className)), ...
                'class %s does not appear in the class list of the schema', self.className);
            
            % list primary key fields
            keyFields = {self.header([self.header.iskey]).name};
            
            if ~expandForeignKeys
                % list parent references
                [classNames,tables] = self.sortForeignKeys(self.parents);
                if ~isempty(classNames)
                    str = sprintf('%s%s',str,sprintf('\n-> %s',classNames{:}));
                    for t = tables
                        % exclude primary key fields of referenced tables from the primary attribute list
                        keyFields = keyFields(~ismember(keyFields, {t.header([t.header.iskey]).name}));
                    end
                end
            end
            
            % additional primary attributes
            for i=find(ismember({self.header.name}, keyFields))
                comment = self.header(i).comment;
                str = sprintf('%s\n%-40s# %s', str, ...
                    sprintf('%-16s: %s', self.header(i).name, self.header(i).type), comment);
            end
            
            % dividing line
            str = sprintf('%s\n---', str);
            
            % list dependent attributes
            dependentFields = {self.header(~[self.header.iskey]).name};
            
            % list other references
            if ~expandForeignKeys
                [classNames,tables] = self.sortForeignKeys(self.references);
                if ~isempty(classNames)
                    str = sprintf('%s%s',str,sprintf('\n-> %s',classNames{:}));
                    for t = tables
                        % exclude primary key fields of referenced tables from header
                        dependentFields = dependentFields(~ismember(dependentFields, {t.header([t.header.iskey]).name}));
                    end
                end
            end
            
            % list remaining attributes
            for i=find(ismember({self.header.name}, dependentFields))
                if self.header(i).isnullable
                    default = '=null';
                elseif strcmp(char(self.header(i).default(:)'), '<<<no default>>>')
                    default = '';
                elseif self.header(i).isNumeric || ...
                        any(strcmp(self.header(i).default,self.mysql_constants))
                    default = ['=' self.header(i).default];
                else
                    default = ['="' self.header(i).default '"'];
                end
                comment = self.header(i).comment;
                str = sprintf('%s\n%-60s# %s', str, ...
                    sprintf('%-28s: %s', [self.header(i).name default], self.header(i).type), ...
                    comment);
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
            
            if ~expandForeignKeys
                str = sprintf('%s%%}\n', str);
            end
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
            % in the table declaration
            self.alter(sprintf('COMMENT="%s"', newComment));
        end
        
        function addAttribute(self, definition)
            % dj.Table/addAttribute - add a new attribute to the
            % table. A full line from the table definition is
            % passed in as "definition".
            sql = fieldToSQL(parseAttrDef(definition, false));
            self.alter(sprintf('ADD COLUMN %s', sql(1:end-2)));
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
            sql = fieldToSQL(parseAttrDef(newDefinition, false));
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
                fieldList, target.table.fullTableName, fieldList));
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
                target.table.schema.dbname, target.table.plainTableName);
            name = self.schema.conn.query(sql);
            if isempty(name.name)
                disp 'No matching foreign key'
            else
                self.alter(sprintf('DROP FOREIGN KEY %s', name.name{1}));
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
            dj.assert(~isempty(indexAttributes) && ...
                all(ismember(indexAttributes, {self.header.name})), ...
                'Index definition contains invalid attribute names');
            % Don't allow indexes that may conflict with foreign keys
            implicitIndexes = self.getImplicitIndexes;
            dj.assert( ~any(arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), ...
                implicitIndexes)), ...
                ['The specified set of attributes is implicitly ' ...
                'indexed because of a foreign key constraint.']);
            % Prevent interference with existing indexes
            allIndexes = self.getDatabaseIndexes;
            dj.assert( ~any(arrayfun( ...
                @(x) isequal(x.attributes, indexAttributes), ...
                allIndexes)), ...
                ['Only one index can be specified for any tuple ' ...
                'of attributes. To change the index type, drop ' ...
                'the exsiting index first.']);
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
            dj.assert(~any(arrayfun( ...
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
                dj.assert(false, 'Could not locate specfied index in database.')
            end
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
                if ~dj.set('suppressPrompt') ...
                        && ~strcmpi('yes', input(sprintf('Update table declaration in %s? yes/no > ',path), 's'))
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
        
        function list = getEnumValues(self, attr)
            % returns the list of allowed values for the attribute attr of type enum
            ix = strcmpi(attr, {self.header.name});
            dj.assert(any(ix), 'Attribute "%s" not found', attr)
            list = regexpi(self.header(ix).type,'^enum\((?<list>''.*'')\)$', 'names');
            dj.assert(~isempty(list), 'Attribute "%s" not of type ENUM', attr)
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
                        if ~strcmpi('yes', input('Proceed anyway? yes/no >','s'))
                            fprintf '\ndrop cancelled\n\n'
                            return
                        end
                    end
                end
                fprintf 'ABOUT TO DROP TABLES: \n'
                tables = cellfun(@(x) dj.Table(x), self.descendants, 'UniformOutput', false);
                tables = [tables{:}];
                for table = tables
                    n = count(init(dj.BaseRelvar,table));
                    fprintf('%20s (%s,%5d tuples)\n', table.fullTableName, table.info.tier, n)
                    doPrompt = doPrompt || n;   % prompt if not empty
                end
                
                % if any table has data, give option to cancel
                doPrompt = doPrompt && ~dj.set('suppressPrompt');  % suppress prompt
                if doPrompt && ~strcmpi('yes', input('Proceed to drop? yes/no >', 's'));
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
        
        
        function declaration = getDeclaration(self)
            % extract the table declaration with the first percent-brace comment
            % block of the matching .m file.
            if ~isempty(self.declaration)
                declaration = self.declaration;
            else
                file = which(self.className);
                dj.assert(~isempty(file), ...
                    'MissingTableDefinition:Could not find table definition file %s', file)
                declaration = readPercentBraceComment(file);
                dj.assert(~isempty(declaration), ...
                    'MissingTableDefnition:Could not find the table declaration in %s', file)
            end
        end
        
        
        
        function create(self)
            if self.isCreated
                return
            end
            [tableInfo, parents, references, fieldDefs, indexDefs] = ...
                parseDeclaration(self.getDeclaration);
            cname = sprintf('%s.%s', tableInfo.package, tableInfo.className);
            dj.assert(strcmp(cname, self.className), ...
                'Table name %s does not match in file %s', cname, self.className)
            
            % compile the CREATE TABLE statement
            tableName = [self.schema.prefix, ...
                dj.Schema.tierPrefixes{strcmp(tableInfo.tier, dj.Schema.allowedTiers)}, ...
                dj.Schema.fromCamelCase(tableInfo.className)];
            
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', self.schema.dbname, tableName);
            
            % add inherited primary key attributes
            primaryKeyFields = {};
            nonKeyFields = {};
            for iRef = 1:length(parents)
                for iField = find([parents{iRef}.table.header.iskey])
                    field = parents{iRef}.table.header(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        primaryKeyFields{end+1} = field.name;   %#ok<AGROW>
                        dj.assert(~field.isnullable, 'primary key header cannot be nullable')
                        sql = sprintf('%s%s', sql, fieldToSQL(field));
                    end
                end
            end
            
            % add the new primary key attribites
            if ~isempty(fieldDefs)
                for iField = find([fieldDefs.iskey])
                    field = fieldDefs(iField);
                    primaryKeyFields{end+1} = field.name;  %#ok<AGROW>
                    dj.assert(~strcmpi(field.default,'NULL'), ...
                        'primary key header cannot be nullable')
                    sql = sprintf('%s%s', sql, fieldToSQL(field));
                end
            end
            
            % add secondary foreign key attributes
            for iRef = 1:length(references)
                for iField = find([references{iRef}.table.header.iskey])
                    field = references{iRef}.table.header(iField);
                    if ~ismember(field.name, [primaryKeyFields nonKeyFields])
                        nonKeyFields{end+1} = field.name; %#ok<AGROW>
                        sql = sprintf('%s%s', sql, fieldToSQL(field));
                    end
                end
            end
            
            % add dependent attributes
            if ~isempty(fieldDefs)
                for iField = find(~[fieldDefs.iskey])
                    field = fieldDefs(iField);
                    nonKeyFields{end+1} = field.name; %#ok<AGROW>
                    sql = sprintf('%s%s', sql, fieldToSQL(field));
                end
            end
            
            % add primary key declaration
            dj.assert(~isempty(primaryKeyFields), 'table must have a primary key')
            str = sprintf(',`%s`', primaryKeyFields{:});
            sql = sprintf('%sPRIMARY KEY (%s),\n',sql, str(2:end));
            
            % add foreign key declarations
            for ref = [parents references]
                fieldList = sprintf('%s,', ref{1}.primaryKey{:});
                fieldList(end)=[];
                sql = sprintf(...
                    '%sFOREIGN KEY (%s) REFERENCES %s (%s) ON UPDATE CASCADE ON DELETE RESTRICT,\n', ...
                    sql, fieldList, ref{1}.table.fullTableName, fieldList);
            end
            
            % add secondary index declarations
            % gather implicit indexes due to foreign keys first
            implicitIndexes = {};
            for fkSource = [parents references]
                isKey = [fkSource{1}.table.header.iskey];
                implicitIndexes{end+1} = {fkSource{1}.table.header(isKey).name}; %#ok<AGROW>
            end
            
            for iIndex = 1:numel(indexDefs)
                dj.assert(all(ismember(indexDefs(iIndex).attributes, ...
                    [primaryKeyFields, nonKeyFields])), ...
                    'Index definition contains invalid attribute names');
                dj.assert(~any(cellfun( ...
                    @(x) isequal(x, indexDefs(iIndex).attributes), ...
                    implicitIndexes)), ...
                    ['The specified set of attributes is implicitly ' ...
                    'indexed because of a foreign key constraint. '...
                    'Cannot create additional index.']);
                fieldList = sprintf('`%s`,', indexDefs(iIndex).attributes{:});
                fieldList(end)=[];
                sql = sprintf(...
                    '%s%s INDEX (%s),\n', ...
                    sql, indexDefs(iIndex).unique, fieldList);
            end
            
            % close the declaration
            sql = sprintf('%s\n) ENGINE = InnoDB, COMMENT "%s$"', sql(1:end-2), tableInfo.comment);
            
            self.schema.reload   % again, ensure that the table does not already exist
            if ~self.isCreated
                % execute declaration
                fprintf \n<SQL>\n
                disp(sql)
                fprintf </SQL>\n\n
                self.schema.conn.query(sql);
                self.schema.reload
            end
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
            for refClassName = [self.references self.parents]
                refObj = dj.Table(self.schema.conn.getPackage(refClassName{1},true));
                indexInfo(end+1).attributes = ...
                    {refObj.header([refObj.header.iskey]).name};  %#ok<AGROW>
            end
        end
        
        
        
        function [classNames,tables] = sortForeignKeys(self, classNames)
            % sort referenced tables so that they reproduce the correct
            % order of primary key attributes
            tables = cellfun(@(x) dj.Table(self.schema.conn.getPackage(x,true)), classNames,'uni',false);
            tables = [tables{:}];
            if isempty(tables)
                classNames = {};
            else
                fkFields = arrayfun(@(x) {x.header([x.header.iskey]).name}, tables,'uni',false);
                fkOrder = cellfun(@(s) cellfun(@(x) find(strcmp(x,{self.header.name})), s), fkFields, 'uni', false);
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
dj.assert(f~=-1, 'Could not open %s', filename)
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

default = field.default;
if strcmpi(default, 'NULL')   % all nullable attributes default to null
    default = 'DEFAULT NULL';
else
    if strcmp(default,'<<<no default>>>')  %DataJoint's special value to indicate no default
        default = 'NOT NULL';
    else
        % enclose value in quotes (even numeric), except special SQL values
        if ~any(strcmpi(default, dj.Table.mysql_constants)) && ...
                ~any(strcmp(default([1 end]), {'''''','""'}))
            default = sprintf('"%s"',default);
        end
        default = sprintf('NOT NULL DEFAULT %s', default);
    end
end
dj.assert(~any(ismember(field.comment, '"\')), ... % TODO: escape isntead
    'illegal characters in attribute comment "%s"', field.comment)
sql = sprintf('`%s` %s %s COMMENT "%s",\n', ...
    field.name, field.type, default, field.comment);
end



function [tableInfo, parents, references, fieldDefs, indexDefs] = parseDeclaration(declaration)
parents = {};
references = {};
fieldDefs = [];
indexDefs = [];

% split into a columnwise cell array
declaration = [strtrim(regexp(declaration,'\n','split')'); ''];

% append the next line to lines that end in a backslash
for i=find(cellfun(@(x) ~isempty(x) && x(end)=='\', declaration'))
    declaration{i} = [declaration{i}(1:end-1) ' ' declaration{i+1}];
    declaration(i+1) = '';
end

% remove empty lines and comment lines
declaration(cellfun(@(x) isempty(strtrim(x)) || strncmp('#',strtrim(x),1), declaration)) = [];

% parse table schema, name, type, and comment
pat = {
    '^(?<package>\w+)\.(?<className>\w+)\s*'  % package.TableName
    '\(\s*(?<tier>\w+)\s*\)\s*'               % (tier)
    '#\s*(?<comment>\S.*\S)$'                 % # comment
    };
tableInfo = regexp(declaration{1}, cat(2,pat{:}), 'names');
dj.assert(numel(tableInfo)==1, ...
    'invalidTableDeclaration:Incorrect syntax in table declaration, line 1')
dj.assert(ismember(tableInfo.tier, dj.Schema.allowedTiers),...
    'invalidTableTier:Invalid tier for table ', tableInfo.className)

if nargout > 1
    % parse field declarations and references
    inKey = true;
    for iLine = 2:length(declaration)
        line = declaration{iLine};
        switch true
            case strncmp(line,'---',3)
                inKey = false;
            case strncmp(line,'->',2)
                % foreign key
                p = feval(strtrim(line(3:end)));
                dj.assert(isa(p, 'dj.Relvar'), 'foreign keys must be base relvars')
                if inKey
                    parents{end+1} = p;     %#ok:<AGROW>
                else
                    references{end+1} = p;   %#ok:<AGROW>
                end
            case regexpi(line, '^(unique\s+)?index[^:]*$')
                % parse index definition
                indexInfo = parseIndexDef(line);
                indexDefs = [indexDefs, indexInfo]; %#ok<AGROW>
            case regexp(line, ['^[a-z][a-z\d_]*\s*' ...       % name
                    '(=\s*\S+(\s+\S+)*\s*)?' ...              % opt. default
                    ':\s*\w[^#]*\S\s*#.*$'])                  % type, comment
                fieldInfo = parseAttrDef(line, inKey);
                fieldDefs = [fieldDefs fieldInfo];  %#ok:<AGROW>
            otherwise
                dj.assert(false, 'Invalid table declaration line "%s"', line)
        end
    end
end
end



function fieldInfo = parseAttrDef(line, inKey)
line = strtrim(line);
pat = {
    '^(?<name>[a-z][a-z\d_]*)\s*'     % field name
    '=\s*(?<default>\S+(\s+\S+)*)\s*' % default value
    ':\s*(?<type>\w[^#]*\S)\s*'       % datatype
    '#\s*(?<comment>\S.*)$'           % comment
    };
fieldInfo = regexp(line, cat(2,pat{:}), 'names');
if isempty(fieldInfo)
    % try no default value
    fieldInfo = regexp(line, cat(2,pat{[1 3 4]}), 'names');
    dj.assert(~isempty(fieldInfo), 'invalid field declaration line "%s"', line)
    fieldInfo.default = '<<<no default>>>';  % special value indicating no default
end
dj.assert(numel(fieldInfo)==1, 'Invalid field declaration "%s"', line)
dj.assert(isempty(regexp(fieldInfo.type,'^bigint', 'once')) ...
    || ~strcmp(fieldInfo.default,'null'), ...
    'invalidDeclaration:BIGINT attributes cannot be nullable in "%s"', line)
fieldInfo.iskey = inKey;
end



function indexInfo = parseIndexDef(line)
line = strtrim(line);
pat = [
    '^(?<unique>UNIQUE)?\s*INDEX\s*' ...  % [UNIQUE] INDEX
    '\((?<attributes>[^\)]+)\)$'          % (attr1, attr2)
    ];
indexInfo = regexpi(line, pat, 'names');
dj.assert(numel(indexInfo)==1 && ~isempty(indexInfo.attributes), ...
    'Invalid index declaration "%s"', line)
attributes = textscan(indexInfo.attributes, '%s', 'delimiter',',');
indexInfo.attributes = strtrim(attributes{1});
dj.assert(numel(unique(indexInfo.attributes)) == numel(indexInfo.attributes), ...
    'Duplicate attributes in index declaration "%s"', line)
end
