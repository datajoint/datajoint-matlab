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
    properties(Constant, GetAccess = private)
        allowedTiers = {'lookup','manual','imported','computed'}   % lookup, manual, imported, or computed
    end
    
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
                if ~isempty(declaration)
                % create the table in the database base on on definition
                    if strcmp('yes',input('Would you like to create it ? yes/no >> ', 's'));
                        dj.Table.create(declaration);
                        ix = strcmp(className, self.schema.classNames);
                    end
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
                self.delete
            end
        end
    end
    
    
    
    methods(Static)
        
        function self = create(declaration)
            % create a new table
            [tableInfo parents references fieldDefs] = dj.Table.parseDeclaration(declaration);
            schemaObj = eval(sprintf('%s.getSchema', tableInfo.packageName));
            
            % compile the CREATE TABLE statement
            sql = sprintf('CREATE TABLE `%s`.`%s (\n', schemaObj.dbname, tableInfo.name);
            
            primaryKey = {};
            primaryFields = [];
            for i=1:length(parents)
                
                primaryKeyFields = parents{i}.fields(parents{i}.fields.iskey);
            end
            
            % execute declaration
            schemaObj.query(sql);
            
            
            
            
            function [sql, indices] = addForeignKeyDeclarations(sql, referencedTables, indices, prefix, propagate)
                % add declarations of foreign keys referring to the referenced tables.
                % Also add any necessary indices as required by InnoDB.
                
                for iRef = 1:numel(referencedTables)
                    referencedFields = getPrimaryKey(referencedTables{iRef});
                    pkeyStr = sprintf(',`%s`',referencedFields{:});
                    pkeyStr = pkeyStr(2:end);
                    
                    % add index if necessary. From MySQL manual:
                    % "In the referencing table, there must be an index where the foreign
                    % key columns are listed as the first columns in the same order."
                    needIndex = true;
                    for iIndex = 1:numel(indices)
                        if isequal(referencedFields,indices{iIndex}(1:min(end,numel(referencedFields))))
                            needIndex = false;
                            break;
                        end
                    end
                    if needIndex
                        sql = sprintf('%s\n    INDEX (%s),', sql, pkeyStr);
                        indices{end+1} = {referencedFields};
                    end
                    
                    sql = sprintf( '%s\n    CONSTRAINT %s_djfk_%d FOREIGN KEY (%s) REFERENCES `%s`.`%s` (%s) %s,'...
                        ,sql,prefix,iRef,pkeyStr,getSchema(referencedTables{iRef}),getTable(referencedTables{iRef}),pkeyStr,propagate);
                end
            end
        end
        
    end
    
    
    
    methods(Static, Access=private)
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
            pat = '\s*(?<packageName>\w+)\.(?<className>\w+)\s*\(\s*(?<tier>\w+)\s*\)\s*#\s*(?<comment>\w.*\w)';
            tableInfo = regexp(declaration{1}, pat, 'names');
            assert(numel(tableInfo)==1,'incorrect syntax is table declaration, line 1')
            assert(ismember(tableInfo.tier, dj.Table.allowedTiers),...
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
                            pat = '\s*(?<name>\w+)\s*=\s*(?<default>\S+(\s+\S+)*)\s*:\s*(?<type>\S.*\S)\s*#\s*(?<comment>\S+(\s+\S+)*)\s*';
                            fieldInfo = regexp(line, pat, 'names');
                            fieldInfo.isKey = inKey;
                            if isempty(fieldInfo)
                                % no default provided
                                pat = '\s*(?<name>\w+)\s*:\s*(?<type>\S.*\S)\s*#\s*(?<comment>\S+(\s+\S+)*)\s*';
                                fieldInfo = regexp(line, pat, 'names');
                                fieldInfo.default = [];
                            end
                            assert(numel(fieldInfo)==1,'Invalid field declaration "%s"',line);
                            fieldDefs(end+1) = fieldInfo;  %#ok:<AGROW>
                    end
                end
            end
        end
    end
end