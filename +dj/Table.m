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
% Note that the class package.ClassName need not exist if the table exists
% in the database. Only if the table does not exist will dj.Table access
% the table definition file.
%
% The syntax of the table definition can be found at
% http://code.google.com/p/datajoint/wiki/TableDeclarationSyntax
%
% Dimitri Yatsenko, 2009, 2010, 2011.

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
                'invalid table identification ''%s''. Should be package.ClassName', className)
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
                    dj.Table.create(declaration);
                    self.schema.reload
                    ix = strcmp(className, self.schema.classNames);
                end
                assert(any(ix), 'Table %s is not found', className);
            end
            
            % table exists, initialize
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
            % (depth<0) and downstream (depth>0) of this table. 
            % Omitting both depths defaults to table.erd(-2,2).
            % Omitting any one of the depths sets the other to zero.
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
                [trash,nodes] = find(self.schema.dependencies(nodes,:));
                upstream = [upstream nodes(:)'];  %#ok:<AGROW>
            end
            
            downstream = [];
            nodes = i;
            for j=1:levels(2)
                [nodes,trash] = find(self.schema.dependencies(:, nodes));
                downstream = [downstream nodes(:)'];  %#ok:<AGROW>
            end
            
            pool = unique([upstream downstream]);
            self.schema.erd(pool)
        end
        
        
        
        
        
        
        function varargout = re(self, expandForeignKeys)
            % reverse engineer the table declaration
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
            
            if ~expandForeignKeys
                str = sprintf('%s%%}\n', str);                
                str = sprintf('%s<END DECLARATION CODE>\n',str);
            end
            
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
            schemaObj = eval(sprintf('%s.getSchema', tableInfo.package));
            
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
            if ~isempty(fieldDefs)
                for iField = find([fieldDefs.iskey])
                    field = fieldDefs(iField);
                    primaryKeyFields{end+1} = field.name;  %#ok<AGROW>
                    assert(~strcmpi(field.default,'null'), ...
                        'primary key fields cannot be nullable')
                    if isempty(field.default)
                        field.default = 'NOT NULL';
                    else
                        % put everything in quotes, even numbers, but not SQL values
                        if ~strcmpi(field.default, 'CURRENT_TIMESTAMP') && ...
                                ~any(strcmp(field.default([1 end]), {'''''','""'}))
                            field.default = ['"' field.default '"'];
                        end
                        field.default = sprintf('NOT NULL DEFAULT %s', field.default);
                    end
                    sql = sprintf('%s  `%s` %s %s COMMENT "%s",\n', ...
                        sql, field.name, field.type, field.default, field.comment);
                end
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
            if ~isempty(fieldDefs)
                for iField = find(~[fieldDefs.iskey])
                    field = fieldDefs(iField);
                    if strcmpi(field.default,'null')
                        field.default = 'DEFAULT NULL';
                    else
                        if isempty(field.default)
                            field.default = 'NOT NULL';
                        else
                            % put everything in quotes, even numbers, but not SQL values
                            if ~any(strcmpi(field.default, {'CURRENT_TIMESTAMP', 'null'})) && ...
                                    ~any(strcmp(field.default([1 end]), {'''''','""'}))
                                field.default = ['"' field.default '"'];
                            end
                            field.default = sprintf('NOT NULL DEFAULT %s', field.default);
                        end
                    end
                    sql = sprintf('%s`%s` %s %s COMMENT "%s",\n', ...
                        sql, field.name, field.type, field.default, field.comment);
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
                        
            % expand <<macros>>.  (TODO: make recursive if necessary)
            for macro = fieldnames(dj.utils.macros)'
                while true
                    ix = find(strcmp(strtrim(declaration), ['<<' macro{1} '>>']),1,'first');
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
                    declaration{i} = [strtrim(declaration{i}(1:pos-1)) ' ' strtrim(declaration{i+1})];
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
                                '^\s*(?<name>[a-z][a-z0-9_]*)\s*' % field name
                                '=\s*(?<default>\S+(\s+\S+)*)\s*' % default value
                                ':\s*(?<type>\S.*\S)\s*'          % datatype
                                '#\s*(?<comment>\S||\S.*\S)\s*$'  % comment  
                                };
                            fieldInfo = regexp(line, cat(2,pat{:}), 'names');
                            if isempty(fieldInfo)
                                % try no default value
                                fieldInfo = regexp(line, cat(2,pat{[1 3 4]}), 'names');
                                assert(~isempty(fieldInfo), 'invalid field declaration line: %s', line);
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
