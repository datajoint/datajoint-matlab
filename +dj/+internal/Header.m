classdef Header < matlab.mixin.Copyable
    % relation header: a list of attributes, their types, etc.
    % This class is used internally by DataJoint and should not
    % be modified.
    
    properties(SetAccess=private)
        info          % table info
        attributes    % array of attributes
        distinct=false% whether to select all the elements or only distinct ones
    end
    
    properties(Access=private,Constant)
        computedTypeString = '<sql_computed>'
    end
    
    properties(Dependent)
        names            % all attribute names
        primaryKey       % primary key attribute names
        dependentFields  % non-primary attribute names
        blobNames        % names of blob attributes
        notBlobs         % names of non-blob attributes
    end
    
    methods(Access=private)
        function self = Header  % prohibit direct instantiation
        end
    end
    
    
    methods
        function names = get.names(self)
            names = {self.attributes.name};
        end
        
        function names = get.primaryKey(self)
            names = self.names([self.attributes.iskey]);
        end
        
        function names = get.dependentFields(self)
            names = self.names(~[self.attributes.iskey]);
        end
        
        function names = get.blobNames(self)
            names = self.names([self.attributes.isBlob]);
        end
        
        function names = get.notBlobs(self)
            names = self.names(~[self.attributes.isBlob]);
        end
        
        function yes = hasAliases(self)
            yes = ~all(arrayfun(@(x) isempty(x.alias), self.attributes));
        end
        
        function n = count(self)
            n = length(self.attributes);
        end
        
        function ret = byName(self, name)
            % get attribute structure by  name
            ix = strcmp(name,{self.attributes.name});
            assert(any(ix),'attribute %s not found', name)
            ret = self.attributes(ix);
        end
    end
    
    
    methods(Static)
        function self = initFromDatabase(schema,tableInfo)  % constructor
            self = dj.internal.Header;
            self.info = tableInfo;
            attrs = schema.conn.query( ...
                sprintf('SHOW FULL COLUMNS FROM `%s` IN `%s`', self.info.name, schema.dbname));
            attrs = dj.struct.rename(attrs,...
                'Field','name','Type','type','Null','isnullable',...
                'Default','default','Key','iskey','Comment','comment');
            attrs = rmfield(attrs,{'Privileges','Collation'});

            attrs.isautoincrement = false(length(attrs.isnullable), 1);
            attrs.isNumeric = false(length(attrs.isnullable), 1);
            attrs.isString = false(length(attrs.isnullable), 1);
            attrs.isAttachment = false(length(attrs.isnullable), 1);
            attrs.isFilepath = false(length(attrs.isnullable), 1);
            attrs.isUuid = false(length(attrs.isnullable), 1);
            attrs.isBlob = false(length(attrs.isnullable), 1);
            attrs.isExternal = false(length(attrs.isnullable), 1);
            attrs.database = cell(length(attrs.isnullable),1);
            attrs.store = cell(length(attrs.isnullable),1);
            attrs.alias = cell(length(attrs.isnullable),1);
            attrs.sqlType = cell(length(attrs.isnullable),1);
            attrs.sqlComment = cell(length(attrs.isnullable),1);
            for i = 1:length(attrs.isnullable)
                attrs.database{i} = schema.dbname;
                attrs.sqlType{i} = attrs.type{i};
                attrs.sqlComment{i} = attrs.comment{i};
                special = regexp(attrs.comment{i}, ...
                                 '^:(?<type>[^:]+):(?<comment>.*)', 'names');
                if ~isempty(special)
                    attrs.type{i} = special.type;
                    attrs.comment{i} = special.comment;
                    category = dj.internal.Declare.matchType(attrs.type{i});
                    assert(any(strcmpi(category, dj.internal.Declare.SPECIAL_TYPES)));
                else
                    category = dj.internal.Declare.matchType(attrs.sqlType{i});
                end 
                attrs.isnullable{i} = strcmpi(attrs.isnullable{i}, 'YES');
                attrs.iskey{i} = strcmpi(char(attrs.iskey{i}), 'PRI');
                attrs.isautoincrement(i) = ~isempty(regexpi(attrs.Extra{i}, ...
                    'auto_increment', 'once'));
                attrs.isNumeric(i) = any(strcmpi(category, {'NUMERIC'}));
                attrs.isString(i) = strcmpi(category, 'STRING');
                attrs.isUuid(i) = strcmpi(category, 'UUID');
                attrs.isBlob(i) = any(strcmpi(category, {'INTERNAL_BLOB', 'EXTERNAL_BLOB'}));
                attrs.isAttachment(i) = any(strcmpi(category, {'INTERNAL_ATTACH', ...
                    'EXTERNAL_ATTACH'}));
                attrs.isFilepath(i) = strcmpi(category, 'FILEPATH');
                if any(strcmpi(category, dj.internal.Declare.EXTERNAL_TYPES))
                    attrs.isExternal(i) = true;
                    attrs.store{i} = attrs.type{i}(regexp(attrs.type{i}, '@', 'once')+1:end);
                end
                % strip field lengths off integer types
                attrs.type{i} = regexprep(sprintf('%s',attrs.type{i}), ...
                    '((tiny|small|medium|big)?int)\(\d+\)','$1');
                attrs.alias{i} = '';
            end

            validFields = [attrs.isNumeric] | [attrs.isString] | [attrs.isBlob] | ...
                [attrs.isUuid] | [attrs.isAttachment] | [attrs.isFilepath];
            if ~all(validFields)
                ix = find(~validFields, 1, 'first');
                error('unsupported field type "%s" in `%s`.`%s`', ...
                    attrs(ix).type, tableName);
            end
            attrs = rmfield(attrs, 'Extra');
            self.attributes = dj.struct.fromFields(attrs);
        end
    end
    
    
    methods
        
        function newHeader = derive(self)
            % copy attribute information but not table information; used to
            % produce headers of derived relations
            newHeader = dj.internal.Header;
            newHeader.attributes = self.attributes;
        end
        
        
        function project(self, params)
            % update header according to the relational projection
            % specification in params.
            
            include = [self.attributes.iskey];  % always include the primary key
            for iAttr=1:length(params)
                if strcmp('*', params{iAttr})
                    include = include | true;   % include all attributes
                else
                    % process a renamed attribute
                    toks = regexp(params{iAttr}, ...
                        '^([a-z]\w*)\s*->\s*(\w+)', 'tokens');
                    if ~isempty(toks)
                        ix = find(strcmp(toks{1}{1}, self.names));
                        if ~length(ix)
                            ix = find(strcmp(toks{1}{1}, {self.attributes.alias}));
                            assert(length(ix)==1, 'Attribute `%s` not found', toks{1}{1});
                            self.attributes(self.count + 1) = self.attributes(ix);
                            self.attributes(self.count).name = self.attributes(self.count).alias;
                            self.attributes(self.count).alias = '';
                            ix = self.count;
                        end
                        assert(length(ix)==1, 'Attribute `%s` not found', toks{1}{1});
                        assert(~ismember(toks{1}{2}, union({self.attributes.alias}, ...
                            self.names)), 'Duplicate attribute alias `%s`', toks{1}{2})
                        self.attributes(ix).name = toks{1}{2};
                        self.attributes(ix).alias = toks{1}{1};
                    else
                        % process a computed attribute
                        % only numeric computations allowed for now, deal with character 
                        % string expressions somehow
                        toks = regexp(params{iAttr}, '(.*\S)\s*->\s*(\w+)', 'tokens');
                        if ~isempty(toks)
                            ix = self.count + 1;
                            self.attributes(ix) = struct(...
                                'name', toks{1}{2}, ...
                                'type', self.computedTypeString, ...
                                'isnullable', false,...
                                'default', [], ...
                                'iskey', false, ...
                                'comment', 'server-side computation', ...
                                'isautoincrement', false, ...
                                'isNumeric', true, ...
                                'isString', false, ...
                                'isBlob', false, ...
                                'isUuid', false, ...
                                'isAttachment', false, ...
                                'isFilepath', false, ...
                                'isExternal', false, ...
                                'store', [], ...
                                'database', [], ...
                                'alias', toks{1}{1}, ...
                                'sqlType', self.computedTypeString, ...
                                'sqlComment', '' ...
                                );
                        else
                            % process a regular attribute
                            ix = find(strcmp(params{iAttr},self.names));
                            assert(~isempty(ix),'DataJoint:missingAttributes',...
                                'Attribute `%s` does not exist', ...
                                params{iAttr})
                        end
                    end
                    include(ix)=true;
                end
            end
            self.attributes = self.attributes(include);
        end
        
        
        function ret = join(hdr1,hdr2)
            % form the header of a relational join
            
            % merge primary keys
            ret = dj.internal.Header;
            ret.attributes = [hdr1.attributes([hdr1.attributes.iskey])
                hdr2.attributes([hdr2.attributes.iskey] & ~ismember(hdr2.names, ...
                    hdr1.primaryKey))];
            
            % error if there are any matching dependent attributes
            commonDependent = intersect(hdr1.dependentFields,hdr2.dependentFields); 
            if ~isempty(commonDependent)
                error(['Matching dependent attribute `%s` must be projected out or ' ...
                    'renamed before relations can be joined.'], commonDependent{1})
            end

            % merge dependent fields
            ret.attributes = [ret.attributes
                hdr1.attributes(~ismember(hdr1.names, ret.names))];
            ret.attributes = [ret.attributes
                hdr2.attributes(~ismember(hdr2.names, ret.names))];
        end
        
        
        function sql = sql(self)
            % make an SQL list of attributes for header
            sql = '';
            assert(~isempty(self.attributes),...
                'DataJoint:missingAttributes','Relation has no attributes');
            for i = 1:length(self.attributes)
                if isempty(self.attributes(i).alias)
                    % if strcmp(self.attributes(i).type,'float')
                    %     sql = sprintf('%s,1.0*`%s` as `%s`', sql, self.names{i}, ...
                    %         self.names{i});  % cast to double to avoid rounding problems
                    % else
                        sql = sprintf('%s,`%s`', sql, self.names{i});
                    % end
                else
                    % aliased attributes
                    % cast to double to avoid rounding problems
                    if strcmp(self.attributes(i).type,'float')
                        sql = sprintf('%s,1.0*`%s` AS `%s`', ...
                            sql, self.attributes(i).alias, self.names{i});
                    elseif strcmp(self.attributes(i).type,self.computedTypeString)
                        sql = sprintf('%s,(%s) AS `%s`', ...
                            sql, self.attributes(i).alias, self.names{i});
                    else
                        sql = sprintf('%s,`%s` AS `%s`', ...
                            sql, self.attributes(i).alias, self.names{i});
                    end
                end
            end
            sql = sql(2:end); % strip leading comma
            
            if self.distinct
                sql = sprintf('DISTINCT %s', sql);
            end
        end
        
        
        function stripAliases(self)
            for i=1:length(self.attributes)
                self.attributes(i).alias = '';
            end
        end
    end

    methods (Access = {?dj.internal.GeneralRelvar})
        function reorderFields(self, order)
            assert(length(order) == length(self.names));
            self.attributes = self.attributes(order);
        end

        function promote(self, keep, varargin)
            if ~keep
                [self.attributes(:).iskey] = deal(false);
                self.distinct = true;
                self.project(varargin); % do the projection
            else
                self.project([varargin, '*']);
            end

            % promote the keys
            for iAttr = 1:numel(varargin)
                %renamed attribute
                toks = regexp(varargin{iAttr}, ...
                    '^([a-z]\w*)\s*->\s*(\w+)', 'tokens');
                if ~isempty(toks)
                    name = toks{1}{2};
                else
                    %computed attribute
                    toks = regexp(varargin{iAttr}, '(.*\S)\s*->\s*(\w+)', 'tokens');
                    if ~isempty(toks)
                        name = toks{1}{2};
                    else
                        %regular attribute
                        name = varargin{iAttr};                            
                    end
                end                
                ix = find(strcmp(name, self.names));
                assert(~isempty(ix), 'DataJoint:missingAttributes', 'Attribute `%s` does not exist', ...
                                name)
                self.attributes(ix).iskey = true;
            end
        end
    end
end
