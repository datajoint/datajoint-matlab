classdef Declare
    % This static class hosts functions to convert DataJoint table definitions into mysql 
    % table definitions, and to declare the corresponding mysql tables.

    properties(Constant)
        UUID_DATA_TYPE = 'binary(16)'
        CONSTANT_LITERALS = {'CURRENT_TIMESTAMP'}
        EXTERNAL_TABLE_ROOT = '~external'
        TYPE_PATTERN = struct( ...
            'NUMERIC', '^((tiny|small|medium|big)?int|decimal|double|float)', ...
            'STRING', '^((var)?char|enum|date|(var)?year|time|timestamp)', ...
            'INTERNAL_BLOB', '^(tiny|medium|long)?blob$', ...
            'EXTERNAL_BLOB', '^blob@(?<store>[a-z]\w*)$', ...
            'INTERNAL_ATTACH', '^attach$', ...
            'EXTERNAL_ATTACH', '^attach@(?<store>[a-z]\w*)$', ...
            'FILEPATH', '^filepath@(?<store>[a-z]\w*)$', ...
            'UUID', '^uuid$' ...
        )
        SPECIAL_TYPES = {'UUID', 'INTERNAL_ATTACH', 'EXTERNAL_ATTACH', 'EXTERNAL_BLOB', ...
            'FILEPATH', 'ADAPTED'}
        % data referenced by a UUID in external tables
        EXTERNAL_TYPES = {'EXTERNAL_ATTACH', 'EXTERNAL_BLOB', 'FILEPATH'}
        % requires packing data
        SERIALIZED_TYPES = {'EXTERNAL_ATTACH', 'INTERNAL_ATTACH', 'EXTERNAL_BLOB', ...
            'INTERNAL_BLOB'}
    end
    
    methods(Static)
        function [sql, external_stores] = declare(table_instance, def)
            % sql = DECLARE(query, definition)  
            %   Parse table declaration and declares the table.
            %   sql:        <string> Generated SQL to create a table.
            %   query:      <class>  DataJoint Table instance.
            %   definition: <string> DataJoint Table definition.
            
            def = strrep(def, '%{', '');
            def = strrep(def, '%}', '');
            def = strtrim(regexp(def,'\n','split')');
            
            % append the next line to lines that end in a backslash
            for i=find(cellfun(@(x) ~isempty(x) && x(end)=='\', def'))
                def{i} = [def{i}(1:end-1) ' ' def{i+1}];
                def(i+1) = '';
            end
            
            % parse table schema, name, type, and comment
            switch true
                    
                case {isa(table_instance, 'dj.internal.UserRelation'), isa(table_instance, ...
                        'dj.Part'), isa(table_instance, 'dj.Jobs'), ...
                        isa(table_instance, 'dj.internal.ExternalTable')}
                    % New-style declaration using special classes for each tier
                    tableInfo = struct;
                    if isa(table_instance, 'dj.Part')
                        tableInfo.tier = 'part';
                    elseif ~isa(table_instance, 'dj.internal.ExternalTable')
                        try
                            specialClass = find(cellfun(@(c) isa(table_instance, c), ...
                                dj.Schema.tierClasses));
                            assert(length(specialClass)==1, ...
                                'DataJoint:TableType:Unknown', ...
                                'Unknown type of UserRelation in %s', class(table_instance))
                            tableInfo.tier = dj.Schema.allowedTiers{specialClass};
                        catch ME
                            if ~strcmp(ME.identifier,'DataJoint:TableType:Unknown')
                                rethrow(ME);
                            else
                                tier = dj.ERD.getTier(table_instance.plainTableName);
                                assert(~isempty(tier), ...
                                    'DataJoint:TableType:Unknown', ...
                                    'Unknown type of UserRelation in %s',class(table_instance))
                                tableInfo.tier = tier;
                            end
                        end
                    end
                    % remove empty lines
                    def(cellfun(@(x) isempty(x), def)) = [];
                    if strncmp(def{1}, '#', 1)
                        tableInfo.comment = strtrim(def{1}(2:end));
                        def = def(2:end);
                    else
                        tableInfo.comment = '';
                    end
                    % remove pure comments
                    def(cellfun(@(x) strncmp('#',strtrim(x),1), def)) = [];                    
                    cname = strsplit(table_instance.className, '.');
                    tableInfo.package = strjoin(cname(1:end-1), '.');
                    tableInfo.className = cname{end};
                    if isa(table_instance, 'dj.Part')
                        tableName = sprintf('%s%s%s', ...
                            table_instance.schema.prefix, ...
                            dj.Schema.tierPrefixes{strcmp(tableInfo.tier, ...
                            dj.Schema.allowedTiers)}, sprintf('%s__%s', ...
                            table_instance.master.plainTableName, ...
                            dj.internal.fromCamelCase(table_instance.className(length( ...
                            table_instance.master.className)+1:end)))); 
                            %#ok<MCNPN>
                    elseif ~isa(table_instance, 'dj.internal.ExternalTable')
                        tableName = sprintf('%s%s%s', ...
                            table_instance.schema.prefix, dj.Schema.tierPrefixes{ ...
                            strcmp(tableInfo.tier, dj.Schema.allowedTiers)}, ...
                            dj.internal.fromCamelCase(tableInfo.className));
                    else
                        tableName = [dj.internal.Declare.EXTERNAL_TABLE_ROOT '_' ...
                            table_instance.store];
                    end
                    
                otherwise
                    % Old-style declaration for backward compatibility
                    
                    % remove empty lines and pure comment lines
                    def(cellfun(@(x) isempty(x) || strncmp('#',x,1), def)) = [];
                    firstLine = strtrim(def{1});
                    def = def(2:end);
                    pat = {
                        '^(?<package>\w+)\.(?<className>\w+)\s*'  % package.TableName
                        '\(\s*(?<tier>\w+)\s*\)\s*'               % (tier)
                        '#\s*(?<comment>.*)$'                     % # comment
                        };
                    tableInfo = regexp(firstLine, cat(2,pat{:}), 'names');
                    assert(numel(tableInfo)==1, ...
                        ['invalidTableDeclaration:Incorrect syntax in table declaration, ' ...
                        'line 1: \n  %s'], firstLine)
                    assert(ismember(tableInfo.tier, dj.Schema.allowedTiers),...
                        'invalidTableTier:Invalid tier for table ', tableInfo.className)
                    cname = sprintf('%s.%s', tableInfo.package, tableInfo.className);
                    assert(strcmp(cname, table_instance.className), ...
                        'Table name %s does not match in file %s', cname, ...
                        table_instance.className)
                    tableName = sprintf('%s%s%s', table_instance.schema.prefix, ...
                        dj.Schema.tierPrefixes{strcmp(tableInfo.tier, ...
                        dj.Schema.allowedTiers)}, dj.internal.fromCamelCase( ...
                        stableInfo.className));
            end
            
            % fields and foreign keys
            inKey = true;
            primaryFields = {};
            foreignKeySql = {};
            indexSql = {};
            attributeSql = {};
            external_stores = {};
            fields = {};
            for iLine = 1:length(def)
                line = def{iLine};
                switch true
                    case strncmp(line,'---',3)
                        inKey = false;                        
                        % foreign key
                    case regexp(line, '^(\s*\([^)]+\)\s*)?->.+$')
                        [fk_attr_sql, fk_sql, newFields, idx_sql] = ...
                            dj.internal.Declare.makeFK( ...
                                line, fields, inKey, ...
                                dj.internal.shorthash(sprintf('`%s`.`%s`', ...
                                table_instance.schema.dbname, tableName)));
                        attributeSql = [attributeSql, fk_attr_sql]; %#ok<AGROW>
                        foreignKeySql = [foreignKeySql, fk_sql]; %#ok<AGROW>
                        indexSql = [indexSql, idx_sql]; %#ok<AGROW>
                        fields = [fields, newFields]; %#ok<AGROW>
                        if inKey
                            primaryFields = [primaryFields, newFields]; %#ok<AGROW>
                        end
                        
                        % index
                    case regexpi(line, '^(unique\s+)?index[^:]*$')
                        indexSql = [indexSql, line]; %#ok<AGROW>
                        
                        % attribute
                    case regexp(line, ['^[a-z][a-z\d_]*\s*' ...       % name
                            '(=\s*\S+(\s+\S+)*\s*)?' ...              % opt. default
                            ':\s*\w.*$'])                             % type, comment
                        fieldInfo = dj.internal.Declare.parseAttrDef(line);
                        assert(~inKey || ~fieldInfo.isnullable, ...
                            'primary key attributes cannot be nullable')
                        if inKey
                            primaryFields{end+1} = fieldInfo.name; %#ok<AGROW>
                        end
                        fields{end+1} = fieldInfo.name; %#ok<AGROW>
                        [attr_sql, store, foreignKeySql] = ...
                            dj.internal.Declare.compileAttribute(fieldInfo, foreignKeySql);
                        attributeSql = [attributeSql, attr_sql]; %#ok<AGROW>
                        if ~isempty(store)
                            external_stores{end+1} = store; %#ok<AGROW>
                        end
                    otherwise
                        error('Invalid table declaration line "%s"', line)
                end
            end
            
            % create declaration
            create_sql = sprintf('CREATE TABLE `%s`.`%s` (\n', table_instance.schema.dbname,...
                tableName);
            % add attribute, primary key, foreign key, and index declaration
            assert(~isempty(primaryFields), 'table must have a primary key')
            table_sql = {attributeSql', {['PRIMARY KEY (`' strjoin(primaryFields, '`,`') ...
                '`)']}, foreignKeySql', indexSql'};
            table_sql = sprintf([strjoin(cat(1, table_sql{:}), ',\n') '\n']);
            % finish the declaration
            engine_sql = sprintf(') ENGINE = InnoDB, COMMENT "%s"', tableInfo.comment);

            sql = sprintf('%s%s%s', create_sql, table_sql, engine_sql);
            
            
            % execute declaration
            if strcmpi(dj.config('loglevel'), 'DEBUG')
                fprintf \n<SQL>\n
                fprintf(sql)
                fprintf \n</SQL>\n\n
            end
        end

        function fieldInfo = parseAttrDef(line)
            % fieldInfo = PARSEATTRDEF(line)
            %   Parse DataJoint line declaration and extracts attributes.
            %   fieldInfo:  <struct> Extracted field attributes.
            %   line:       <string> DataJoint definition, single line.
            line = strtrim(line);
            assert(~isempty(regexp(line, '^[a-z][a-z\d_]*', 'once')), ...
                'invalid attribute name in %s', line)
            pat = {
                '^(?<name>[a-z][a-z\d_]*)\s*'     % field name
                ['=\s*(?<default>".*"|''.*''|\w+|[-+]?[0-9]*\.?[0-9]+([eE][-+]?' ...
                    '[0-9]+)?)\s*'] % default value
                [':\s*(?<type>\w[@\w\s]+(\(.*\))?(\s*[aA][uU][tT][oO]_[iI][nN]' ...
                    '[cC][rR][eE][mM][eE][nN][tT])?)\s*']       % datatype
                '#(?<comment>.*)'           % comment
                '$'  % end of line
                };
            hasDefault = ~isempty(regexp(line, '^\w+\s*=', 'once'));
            if ~hasDefault
                pat{2} = '';
            end
            for sub = {[1 2 3 4 5] [1 2 3 5]}  % with and without the comment
                pattern = cat(2,pat{sub{:}});
                fieldInfo = regexp(line, pattern, 'names');
                if ~isempty(fieldInfo)
                    break
                end
            end
            assert(numel(fieldInfo)==1, 'Invalid field declaration "%s"', line)
            if ~isfield(fieldInfo,'comment')
                fieldInfo.comment = '';
            end
            fieldInfo.comment = strtrim(fieldInfo.comment);
            if ~hasDefault
                fieldInfo.default = '';
            end
            assert(isempty(regexp(fieldInfo.type,'^bigint', 'once')) ...
                || ~strcmp(fieldInfo.default,'null'), ...
                'BIGINT attributes cannot be nullable in "%s"', line)
            fieldInfo.isnullable = strcmpi(fieldInfo.default,'null');
        end

        function [all_attr_sql, fk_sql, newattrs, idx_sql] = makeFK(line, existingFields, ...
                                                                    inKey, hash)
            % [sql, newattrs] = MAKEFK(sql, line, existingFields, inKey, hash)
            %   Add foreign key to SQL table definition.
            %   sql:            <string> Modified in-place SQL to include foreign keys.
            %   newattrs:       <cell_array> Extracted new field attributes.
            %   line:           <string> DataJoint definition, single line.
            %   existingFields: <struct> Existing field attributes.
            %   inKey:          <logical> Set as primary key.
            %   hash:           <string> Current hash as base.
            fk_sql = '';
            all_attr_sql = '';
            idx_sql = '';
            pat = ['^(?<newattrs>\([\s\w,]*\))?' ...
                '\s*->\s*' ...
                '(?<options>\[[\s\w,]*\])?' ...
                '\s*' ...
                '(?<cname>\w+\.[A-Z][A-Za-z0-9]*)' ...
                '\w*' ...
                '(?<attrs>\([\s\w,]*\))?' ...
                '\s*(#.*)?$'];
            fk = regexp(line, pat, 'names');
            if exist(fk.cname, 'class')
                rel = feval(fk.cname);
                assert(isa(rel, 'dj.Relvar'), 'class %s is not a DataJoint relation', fk.cname)
            else
                rel = dj.Relvar(fk.cname);
            end
            
            % parse and validate the attribute lists
            attrs = strsplit(fk.attrs, {' ',',','(',')'});
            options = strsplit(fk.options, {' ',',','[',']'});
            newattrs = strsplit(fk.newattrs, {' ',',','(',')'});
            attrs(cellfun(@isempty, attrs))=[];
            options(cellfun(@isempty, options))=[];
            newattrs(cellfun(@isempty, newattrs))=[];
            assert(all(cellfun(@(a) ismember(a, rel.primaryKey), attrs)), ...
                'All attributes in (%s) must be in the primary key of %s', ...
                strjoin(attrs, ','), rel.className)
            assert(~inKey || ~any(strcmpi('NULLABLE', options)), ...
                                  sprintf(['Primary dependencies cannot be ' ...
                                           'nullable in line "%s"'], line));
            if length(newattrs)==1 
                % unambiguous single attribute
                if length(rel.primaryKey)==1
                    attrs = rel.primaryKey;
                elseif isempty(attrs) && length(setdiff(rel.primaryKey, existingFields))==1
                    attrs = setdiff(rel.primaryKey, existingFields);
                end
            end
            assert(length(attrs) == length(newattrs) , ...
                'Mapped fields (%s) and (%s) must match in the foreign key.', ...
                strjoin(newattrs,','), strjoin(attrs,','))
            
            % prepend unspecified primary key attributes that have not yet been
            % included 
            pk = rel.primaryKey;
            pk(ismember(pk,attrs) | ismember(pk,existingFields))=[];
            attrs = [pk attrs];
            newattrs = [pk newattrs];
            
            % fromFields and toFields are sorted in the same order as
            % ref.rel.tableHeader.attributes
            [~, ix] = sort(cellfun(@(a) find(strcmp(a, rel.primaryKey)), attrs));
            attrs = attrs(ix);
            newattrs = newattrs(ix);
            
            for i=1:length(attrs)
                fieldInfo = rel.tableHeader.attributes(strcmp(attrs{i}, ...
                    rel.tableHeader.names));
                fieldInfo.name = newattrs{i};
                fieldInfo.isnullable = logical(~inKey*any(strcmpi('NULLABLE', options)));
                [attr_sql, ~, ~] = dj.internal.Declare.compileAttribute(fieldInfo, []);
                all_attr_sql = sprintf('%s%s,\n', all_attr_sql, attr_sql);
            end
            all_attr_sql = all_attr_sql(1:end-2);
            
            fkattrs = rel.primaryKey;
            fkattrs(ismember(fkattrs, attrs))=newattrs;
            hash = dj.internal.shorthash([{hash rel.fullTableName} newattrs]);
            fk_sql = sprintf(...
                ['%sCONSTRAINT `%s` FOREIGN KEY (%s) REFERENCES %s (%s) ' ...
                'ON UPDATE CASCADE ON DELETE RESTRICT'], fk_sql, hash, ...
                backquotedList(fkattrs), rel.fullTableName, backquotedList(rel.primaryKey));
            if any(strcmpi('UNIQUE', options))
                idx_sql = sprintf('UNIQUE INDEX (%s)', ['`' strjoin(newattrs, '`,`') '`']);
            end
        end

        function [field, foreignKeySql] = substituteSpecialType(field, category, foreignKeySql)
            % field = SUBSTITUTESPECIALTYPE(field, category)
            %   Substitute DataJoint type with sql type.
            %   field:      <struct> Modified in-place field attributes.
            %   category:   <string> DataJoint type match based on TYPE_PATTERN.
            if strcmpi(category, 'UUID')
                field.type = dj.internal.Declare.UUID_DATA_TYPE;
            elseif strcmpi(category, 'INTERNAL_ATTACH')
                field.type = 'LONGBLOB';
            elseif any(strcmpi(category, dj.internal.Declare.EXTERNAL_TYPES))
                field.store = strtrim(field.type((strfind(field.type,'@')+1):end));
                field.type = dj.internal.Declare.UUID_DATA_TYPE;
                foreignKeySql = [foreignKeySql, sprintf( ...
                    ['FOREIGN KEY (`%s`) REFERENCES `{database}`.`%s_%s` (`hash`) ON ' ...
                    'UPDATE RESTRICT ON DELETE RESTRICT'], field.name, ...
                    dj.internal.Declare.EXTERNAL_TABLE_ROOT, field.store)]; %#ok<AGROW>
            end
        end

        function [sql, store, foreignKeySql] = compileAttribute(field, foreignKeySql)
            % sql = COMPILEATTRIBUTE(field)
            %   Convert the structure field with header {'name' 'type' 'default' 'comment'}
            %       to the SQL column declaration.
            %   sql:    <string> Generated SQL for field statement.
            %   field:  <struct> Parsed DataJoint attribute declaration.        
            if field.isnullable   % all nullable attributes default to null
                default = 'DEFAULT NULL';
            else
                default = 'NOT NULL';
                if ~isempty(field.default)
                    % enclose value in quotes (even numeric), except special 
                    % SQL values or values already enclosed by the user
                    if any(strcmpi(field.default, ...
                            dj.internal.Declare.CONSTANT_LITERALS)) || ...
                            ismember(field.default(1), {'''', '"'})
                        default = sprintf('%s DEFAULT %s', default, field.default);
                    else
                        default = sprintf('%s DEFAULT "%s"', default, field.default);
                    end
                end
            end
            % Escape characters: "/
            field.comment = regexprep(field.comment, '(["\/])', '\\\\$1');

            category = dj.internal.Declare.matchType(field.type);
            store = [];
            if any(strcmpi(category, dj.internal.Declare.SPECIAL_TYPES))
                field.comment = [':' strip(field.type) ':' field.comment];
                [field, foreignKeySql] = dj.internal.Declare.substituteSpecialType(field, ...
                    category, foreignKeySql);
                if isfield(field, 'store')
                    store = field.store;                    
                end
            end
            sql = sprintf('`%s` %s %s COMMENT "%s"', ...
                field.name, strtrim(field.type), default, field.comment);
        end

        function definition = getDefinition(self)
            % definition = GETDEFINITION(self)
            %   Extract the table declaration with the first percent-brace comment block of
            %       the matching .m file.
            %   definition: <string> DataJoint definition extracted from classdef.
            %   self:       <class> DataJoint Table instance.
            file = which(self.className);
            assert(~isempty(file), ...
                'MissingTableDefinition:Could not find table definition file %s', ...
                self.className)
            definition = readPercentBraceComment(file);
            assert(~isempty(definition), ...
                'MissingTableDefnition:Could not find the table declaration in %s', ...
                file)
        end

        function matched_type = matchType(attribute_type)
            % matched_type = MATCHTYPE(attribute_type)
            %   Classify DataJoint definition as DataJoint types based on TYPE_PATTERN.
            %   matched_type:   <string> DataJoint classified category.
            %   attribute_type: <string> DataJoint defined type.
            fn = fieldnames(dj.internal.Declare.TYPE_PATTERN);
            for k=1:numel(fn)
                if ~isempty(regexpi(strtrim(attribute_type), ...
                        dj.internal.Declare.TYPE_PATTERN.(fn{k})))
                    matched_type = fn{k};
                    break;
                end
            end
            assert(exist('matched_type','var') == 1, ...
                'UnsupportedType: Attribute type ''%s'' is not a valid type.', ...
                attribute_type);
        end
    end
end

function str = backquotedList(arr)
    % Convert cell array to backquoted, comma-delimited string.
    str = sprintf('`%s`,', arr{:});
    str(end)=[];
end

function str = readPercentBraceComment(filename)
    % Read the initial comment block %{ ... %} in filename

    f = fopen(filename, 'rt');
    assert(f~=-1, 'Could not open %s', filename)
    str = ['%{' newline];

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
    str = [str '%}' newline];
    fclose(f);
end