classdef Header < matlab.mixin.Copyable
    % relation header: a list of attributes, their types, etc.
    % This class is used internally by DataJoint and should not
    
    properties(SetAccess=private)
        info          % table info
        attributes    % array of attributes
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
            self = dj.Header;
            self.info = tableInfo;
            attrs = schema.conn.query(...
                sprintf('SHOW FULL COLUMNS FROM `%s` IN `%s`', self.info.name, schema.dbname));
            attrs = dj.struct.rename(attrs,...
                'Field','name','Type','type','Null','isnullable',...
                'Default','default','Key','iskey','Comment','comment');
            attrs = rmfield(attrs,{'Privileges','Collation'});
            
            attrs.isnullable = strcmpi(attrs.isnullable,'YES');
            attrs.iskey = strcmp(attrs.iskey,'PRI');
            attrs.isautoincrement = ~cellfun(@(x) isempty(regexpi(x, ...
                'auto_increment', 'once')), attrs.Extra);
            attrs.isNumeric = ~cellfun(@(x) isempty(regexp(sprintf('%s',x), ...
                '^((tiny|small|medium|big)?int|decimal|double|float)', 'once')), attrs.type);
            attrs.isString = ~cellfun(@(x) isempty(regexp(sprintf('%s',x), ...
                '^((var)?char|enum|date|time|timestamp)','once')), attrs.type);
            attrs.isBlob = ~cellfun(@(x) isempty(regexp(sprintf('%s',x), ...
                '^(tiny|medium|long)?blob', 'once')), attrs.type);
            % strip field lengths off integer types
            attrs.type = cellfun(@(x) regexprep(sprintf('%s',x), ...
                '((tiny|small|medium|big)?int)\(\d+\)','$1'), attrs.type, 'UniformOutput', false);
            attrs.alias = repmat({''}, length(attrs.name),1);
            validFields = [attrs.isNumeric] | [attrs.isString] | [attrs.isBlob];
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
            newHeader = dj.Header;
            newHeader.attributes = self.attributes;
        end
        
        
        function project(self, params)
            % update header according to the relational projection
            % specification in params.
            
            include = [self.attributes.iskey];  % always include the primary key
            for iAttr=1:length(params)
                if strcmp('*',params{iAttr})
                    include = include | true;   % include all attributes
                else
                    % process a renamed attribute
                    toks = regexp(params{iAttr}, ...
                        '^([a-z]\w*)\s*->\s*(\w+)', 'tokens');
                    if ~isempty(toks)
                        ix = find(strcmp(toks{1}{1},self.names));
                        assert(length(ix)==1,'Attribute `%s` not found',toks{1}{1});
                        assert(~ismember(toks{1}{2},union({self.attributes.alias},self.names)),...
                            'Duplicate attribute alias `%s`',toks{1}{2})
                        self.attributes(ix).name = toks{1}{2};
                        self.attributes(ix).alias = toks{1}{1};
                    else
                        % process a computed attribute
                        toks = regexp(params{iAttr}, '(.*\S)\s*->\s*(\w+)', 'tokens');
                        if ~isempty(toks)
                            ix = self.count + 1;
                            self.attributes(ix) = struct(...
                                'name', toks{1}{2}, ...
                                'type','<sql_computed>',...
                                'isnullable', false,...
                                'default', [], ...
                                'iskey', false, ...
                                'comment','server-side computation', ...
                                'isautoincrement', false, ...
                                'isNumeric', true, ...  % only numeric computations allowed for now, deal with character string expressions somehow
                                'isString', false, ...
                                'isBlob', false, ...
                                'alias', toks{1}{1});
                        else
                            % process a regular attribute
                            ix = find(strcmp(params{iAttr},self.names));
                            assert(~isempty(ix), 'Attribute `%s` does not exist', params{iAttr})
                        end
                    end
                    include(ix)=true;
                end
            end
            self.attributes = self.attributes(include);
        end
        
        
        function ret = join(hdr1,hdr2)
            % form the header of relational join
            
            % merge primary keys
            ret = dj.Header;
            ret.attributes = [hdr1.attributes([hdr1.attributes.iskey])
                hdr2.attributes([hdr2.attributes.iskey] & ~ismember(hdr2.names, hdr1.primaryKey))];
            
            % merge dependent fields
            ret.attributes = [ret.attributes
                hdr1.attributes(~ismember(hdr1.names, ret.names))];
            ret.attributes = [ret.attributes
                hdr2.attributes(~ismember(hdr2.names, ret.names))];
        end
        
        
        function sql = sql(self)
            % make an SQL list of attributes for header
            sql = '';
            assert(~isempty(self.attributes))
            for i = 1:length(self.attributes)
                if isempty(self.attributes(i).alias)
                    sql = sprintf('%s,`%s`', sql, self.names{i});
                else
                    sql = sprintf('%s,(%s) AS `%s`', ...
                        sql, self.attributes(i).alias, self.names{i});
                end
            end
            sql = sql(2:end);
        end
        
        
        function stripAliases(self)
            for i=1:length(self.attributes)
                self.attributes(i).alias = '';
            end
        end
    end
end