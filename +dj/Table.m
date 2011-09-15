% dj.Table provides the data definition interface to a single table in the
% database.
%
% Initialization:
%    table = dj.Table('package.Table');
%    table = dj.Table('<declarationFilepath>.m');
%
% Syntax 1 can be used to retrieve the definition of an existing
% table not yet associated with a base relvar class.
%
% Syntax 2 is used in base relvar classes to instantiate the constant table
% property as table = dj.Table(mfilename('fullpath')). The filepath must
% specify a valid matlab file.

% In this case, the constructor reads the first multi-line comment block
% that begins with %{ all by itself and ends with %} all by itself.
% Incidentally, this block is ignored by matlab's help function.
%

classdef (Sealed) Table < handle
    
    properties(SetAccess = private)
        schema           % handle to a schema object
        info             % name, tier, comment.  See self.Schema
        primaryKey       % a column cell array containing primary key names
        fields           % structure array describing fields
    end
    
    methods
        function self = Table(str)
            %   obj = dj.Table('package.className') or obj = dj.Table(declarationFile);
            %
            % When the declaration filename is provided, the constructor
            % creates the table in the database if does not already exist.
            %
            switch true
                % SYNTAX 1
                case nargin==1 && ischar(str) && ~isempty(regexp(str, '^\w+\.\w+$', 'once'))
                    className = str;
                    try
                        self.schema = eval([regexp(str,'^\w+','match','once'), '.getSchema']);
                        assert(isa(self.schema, 'dj.Schema'));
                    catch  %#ok
                        error('invalid schema name in %s', str);
                    end
                    declaration = '';
                    
                    % SYNTAX 2
                case nargin==1 && ischar(str) && any(exist(str,'file')==2)
                    % read the table declaration from the leading comment of the specified file
                    declaration = dj.utils.readPreamble(str);
                    
                otherwise
                    error 'invalid constructor call'
            end
            
            if ~isempty(declaration)
                % parse declaration
                tableInfo = dj.Table.parseDeclaration(declaration);
                self.schema = eval(sprintf('%s.getSchema', tableInfo.packageName));
                className = sprintf('%s.%s', tableInfo.packageName, tableInfo.className);
            end
            
            % check if the table exists in the schema
            ix = strcmp(className, self.schema.classNames);
            
            if ~any(ix)
                fprintf('table %s not found in schema %s:%s\n', ...
                    className, self.schema.host, self.schema.dbname);

                % create the table
                if ~isempty(declaration)
                    dj.Table.create(declaration);
                    self.schema.reload
                    ix = strcmp(className, self.schema.classNames);
                end
                assert(any(ix), 'Table %s is not found', className);
            end
            
            % table already exists, initialize
            self.info = self.schema.tables(ix);
            self.fields = self.schema.fields(strcmp(self.info.name, {self.schema.fields.table}));
            self.primaryKey = {self.fields([self.fields.iskey]).name};
        end
        
        
        
        
        function display(self)
            display@handle(self)
            disp(self.re(true))
            fprintf \n
        end
        
        
        
        function erd(self, depth1, depth2)
            % plot the entity relationship diagram of this and connected tables
            % table.erd([depth1[,depth2]])
            % depth1 and depth2 specify the connectivity radius upstream
            % (depth<0) and downstream (depth>0) of this table. Omitting
            % either of these arguments defaults to table.erd(-2,2).
            %
            % Example:
            %   t = dj.Table('vis2p.Scans');
            %   t.erd       % plot two levels above and below
            %   t.erd( 2);  % plot dependents up to 2 levels below
            %   t.erd(-1);  % plot only immediate ancestors
            
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
            
            upstream = i;
            nodes = i;
            for j=1:-levels(1)
                [~,nodes] = find(self.schema.dependencies(nodes,:));
                upstream = [upstream nodes(:)'];  %#ok:<AGROW>
            end
            
            downstream = [];
            nodes = i;
            for j=1:levels(2)
                [nodes,~] = find(self.schema.dependencies(:, nodes));
                downstream = [downstream nodes(:)'];  %#ok:<AGROW>
            end
            
            pool = unique([upstream downstream]);
            self.schema.erd(pool)
        end
        
        
        
        
        
        
        function varargout = re(self, expandForeignKeys)
            % reverse engineer the table declaration
            expandForeignKeys = nargin>=2 && expandForeignKeys;
            
            className = [self.schema.package '.' dj.utils.camelCase(self.info.name)];
            str = sprintf('%s (%s) # %s\n', ...
                className, self.info.tier, self.info.comment);
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
                    c = sprintf('\n->');
                    for i=refIds
                        str = sprintf('%s%s%s', str, c, self.schema.classNames{i});
                        c = ',';
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
            
            if nargout==0
                fprintf('\n%s\n', str)
            else
                varargout{1} = str;
            end
        end
        
        
        
        function isempty(self) %#ok
            % throws error to prevent ambiguous meaning
            error 'dj.Table/isempty is not defined. Use dj.Relvar/isempty'
        end
        
        function length(self)  %#ok
            % throws error to prevent ambiguous meaning
            error 'dj.Table/length is not defined. Use dj.Relvar/length'
        end
        
        
        function drop(self)
            % remove the table from the database
            assert(isempty(dj.Relvar(self)), 'The table must be empty before it can be dropped')
            
            refs = find(self.schema.dependencies(:,strcmp({self.schema.tables.name},self.info.name)));
            if ~isempty(refs)
                error('The table cannot be dropped because it''s referenced by %s', self.schema.classNames{refs})
            else
                self.schema.query(sprintf('DROP TABLE `%s`.`%s`', self.schema.dbname, self.info.name))
                fprintf('Dropped table `%s`.`%s`\n', self.schema.dbname, self.info.name)
                self.schema.reload
            end
        end
    end
    
    
    
    methods(Static, Access=private)
        
        function create(declaration)
            % create a new table
            disp 'CREATING TABLE IN THE DATABASE: ';
                        
            [tableInfo parents references fieldDefs] = dj.Table.parseDeclaration(declaration);
            schemaObj = eval(sprintf('%s.getSchema', tableInfo.packageName));
            
            % compile the CREATE TABLE statement
            tableName = [...
                dj.utils.tierPrefixes{strcmp(tableInfo.tier, dj.utils.allowedTiers)}, ...
                dj.utils.camelCase(tableInfo.className, true)];
            
            sql = sprintf('CREATE TABLE `%s`.`%s` (\n', schemaObj.dbname, tableName);
            
            % add inherited primary key fields
            primaryKeyFields = {};
            for iRef = 1:length(parents)
                for iField=find([parents{iRef}.fields.iskey])
                    field = parents{iRef}.fields(iField);
                    if ~ismember(field.name, primaryKeyFields)
                        primaryKeyFields{end+1} = field.name;   %#ok<AGROW>
                        assert(~field.isnullable);   %primary key fields cannot be nullable
                        if strcmp(field.default, '<<<none>>>')
                            field.default = 'NOT NULL';
                        else
                            field.default = sprintf('NOT NULL DEFAULT "%s"', field.default);
                        end
                        sql = sprintf('%s  `%s` %s %s COMMENT "%s",\n', ...
                            sql, field.name, field.type, field.default, field.comment);
                    end
                end
            end
            
            % add the new primary key fields
            for iField = find([fieldDefs.iskey])
                field = fieldDefs(iField);
                primaryKeyFields{end+1} = field.name;  %#ok<AGROW>
                assert(~strcmpi(field.default,'null'), ...
                    'primary key fields cannot be nullable')
                if isempty(field.default)
                    field.default = 'NOT NULL';
                else
                    if ~any(strcmp(field.default([1 end]), {'''''','""'}))
                        field.default = ['"' default '"'];
                    end
                    field.default = sprint('NOT NULL DEFAULT %s', field.default);
                end
                sql = sprintf('%s  `%s` %s %s COMMENT "%s",\n', ...
                    sql, field.name, field.type, field.default, field.comment);
            end
            
            % add references
            for iRef = 1:length(references)
                field = references{iRef}.fields(iField);
                if ~ismember(field.name, primaryKeyFields)
                    if field.isnullable
                        field.default = 'DEFAULT NULL';  % all nullable fields default to null
                    else
                        if strcmp(field.default, '<<<none>>>')
                            field.default = 'NOT NULL';
                        else
                            field.default = sprintf('NOT NULL DEFAULT "%s"', field.default);
                        end
                    end
                    sql = sprintf('%s  `%s` %s %s COMMENT "%s",\n', ...
                        sql, field.name, field.type, field.default, field.comment);
                end
            end
            
            % add dependent fields
            for iField = find(~fieldDefs.iskey)
                field = fieldDefs(iField);
                if strcmpi(field.default,'null')
                    field.default = 'DEFAULT NULL';
                else
                    if isempty(field.default)
                        field.default = 'NOT NULL';
                    else
                        if ~any(strcmp(field.default([1 end]), {'''''','""'}))
                            field.default = ['"' default '"'];
                        end
                        field.default = sprint('NOT NULL DEFAULT %s', field.default);
                    end
                end
                sql = sprintf('%s`%s` %s %s COMMENT "%s",\n', ...
                    sql, field.name, field.type, field.default, field.comment);
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
            sql = sprintf('%s\n) ENGINE = InnoDB, COMMENT "%s"', sql(1:end-2), tableInfo.comment);
            
            disp <SQL>
            disp(sql)
            disp </SQL>

            % execute declaration
            schemaObj.query(sql);            
        end
        
        
        
        function [tableInfo parents references fieldDefs] = parseDeclaration(declaration)
            parents = {};
            references = {};
            fieldDefs = [];
            
            if ischar(declaration)
                declaration = dj.utils.str2cell(declaration);
            end
            assert(iscellstr(declaration), 'declaration must be a multiline string or a cellstr');
            
            % remove empty lines
            declaration(cellfun(@(x) isempty(strtrim(x)), declaration)) = [];
            
            % parse table schema, name, type, and comment
            pat = {
                '^\s*(?<packageName>\w+)\.(?<className>\w+)\s*'  % package.TableName
                '\(\s*(?<tier>\w+)\s*\)\s*'                      % (tier)
                '#\s*(?<comment>\S.*\S)\s*$'                     % # comment
                };
            tableInfo = regexp(declaration{1}, cat(2,pat{:}), 'names');
            assert(numel(tableInfo)==1,'incorrect syntax is table declaration, line 1')
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
                            assert(isa(p, 'dj.Relvar'), 'foreign keys must be base relvars')
                            if inKey
                                parents{end+1} = p;     %#ok:<AGROW>
                            else
                                references{end+1} = p;   %#ok:<AGROW>
                            end
                        otherwise
                            % parse field definition
                            pat = {
                                '^\s*(?<name>\w+)\s*'                % attribute name
                                '=\s*(?<default>\S+(\s+\S+)*)\s*'    % default value
                                ':\s*(?<type>\S.*\S)\s*'             % datatype
                                '#\s*(?<comment>\S.*\S*)\s*$'   % comment
                                };
                            fieldInfo = regexp(line, cat(2,pat{:}), 'names');
                            if isempty(fieldInfo)
                                % try no default value
                                fieldInfo = regexp(line, cat(2,pat{[1 3 4]}), 'names');
                                fieldInfo.default = [];
                            end
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