% dj.internal.External - an external static method class.
% classdef ExternalTable < dj.internal.Table
classdef ExternalTable < dj.Relvar
    properties
        store
        spec
    end
    properties (Hidden)
        connection
    end
    methods
        function self = ExternalTable(connection, store, schema)
%             curr_schema = self.schema;
            self.store = store;
            self.schema = schema;
            self.connection = connection;
            stores = dj.config('stores');
            assert(isstruct(stores.(store)), 'Store `%s` not configured as struct.', store);
            assert(any(strcmp('store_config', fieldnames(stores.(store)))), 'Store `%s` missing `store_config` key.', store);
            assert(isstruct(stores.(store).store_config), 'Store `%s` set `store_config` as `%s` but expecting `struct`.', store, class(stores.(store).store_config));
            assert(any(strcmp('protocol', fieldnames(stores.(store).store_config))), 'Store `%s` missing `store_config.protocol` key.', store);
            if isstring(stores.(store).store_config.protocol)
                storePlugin = char(stores.(store).store_config.protocol);
            else
                assert(ischar(stores.(store).store_config.protocol), 'Store `%s` set `store_config.protocol` as `%s` but expecting `char||string`.', store, class(stores.(store).store_config.protocol));
                storePlugin = stores.(store).store_config.protocol;
            end

            storePlugin(1) = upper(storePlugin(1));
            try
                config = buildConfig(stores.(store), dj.store_plugins.(storePlugin).validation_config, store);
                self.spec = dj.store_plugins.(storePlugin)(config);
            catch ME
                if strcmp(ME.identifier,'MATLAB:undefinedVarOrClass')
                    % Throw error if plugin not found
                    error('DataJoint:StorePlugin:Missing', ...
                        'Missing store plugin `%s`.', storePlugin);
                else
                    rethrow(ME);
                end
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
            def = {...
            '# external storage tracking'
            'hash  : uuid    #  hash of contents (blob), of filename + contents (attach), or relative filepath (filepath)'
            '---'
            'size      :bigint unsigned     # size of object in bytes'
            'attachment_name=null : varchar(255)  # the filename of an attachment'
            'filepath=null : varchar(1000)  # relative filepath or attachment filename'
            'contents_hash=null : uuid      # used for the filepath datatype'
            'timestamp=CURRENT_TIMESTAMP  :timestamp   # automatic timestamp'
            };
            def = sprintf('%s\n',def{:});

            [sql, ~] = dj.internal.Declare.declare(self, def);
            self.schema.conn.query(sql);
            self.schema.reload
        end
        function uuid_path = make_uuid_path(self, uuid, suffix)
            uuid = strrep(uuid, '-', '');
            uuid_path = self.spec.make_external_filepath([self.schema.dbname '/' strjoin(subfold(uuid, self.spec.blob_config.subfolding), '/') '/' uuid suffix]);
        end
        function uuid = upload_buffer(self, blob)
            packed_cell = mym('serialize {M}', blob);
            % https://www.mathworks.com/matlabcentral/fileexchange/25921-getmd5
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            self.spec.upload_buffer(packed_cell{1}, self.make_uuid_path(uuid, ''));
            %  insert tracking info
            sql = sprintf('INSERT INTO %s (hash, size) VALUES (X''%s'', %i) ON DUPLICATE KEY UPDATE timestamp=CURRENT_TIMESTAMP', self.fullTableName, uuid, length(packed_cell{1}));
            self.connection.query(sql);
        end
        function blob = download_buffer(self, uuid)
            blob = mym('deserialize', uint8(self.spec.download_buffer(self.make_uuid_path(uuid, ''))));
        end
        function refs = references(self)
            sql = {...
            'SELECT concat(''`'', table_schema, ''`.`'', table_name, ''`'') as referencing_table, column_name '
            'FROM information_schema.key_column_usage '
            'WHERE referenced_table_name="{S}" and referenced_table_schema="{S}"'
            };
            sql = sprintf('%s',sql{:});
            refs = self.connection.query(sql, self.plainTableName, self.schema.dbname);
        end
        function used = used(self)
            ref = self.references;
            used = self & cellfun(@(column, table) sprintf('hex(`hash`) in (select hex(`%s`) from %s)', column, table), ref.column_name, ref.referencing_table, 'UniformOutput', false);
        end
        function unused = unused(self)
            ref = self.references;
            unused = self - cellfun(@(column, table) sprintf('hex(`hash`) in (select hex(`%s`) from %s)', column, table), ref.column_name, ref.referencing_table, 'UniformOutput', false);
        end
        function paths = fetch_external_paths(self, varargin)
            external_content = fetch(self, 'hash', 'attachment_name', 'filepath', varargin{:});
            paths = cell(length(external_content),1);
            for i = 1:length(external_content)
                if ~isempty(external_content(i).attachment_name)
                elseif ~isempty(external_content(i).filepath)
                else
                    paths{i}{2} = self.make_uuid_path(external_content(i).hash, '');
                end
                paths{i}{1} = external_content(i).hash;
            end
        end
        function delete(self, delete_external_files, limit)
            if ~delete_external_files
                delQuick(self.unused);
            else
                if ~isempty(limit)
                    items = fetch_external_paths(self.unused, sprintf('LIMIT %i', limit));
                else
                    items = fetch_external_paths(self.unused);
                end
                for i = 1:length(items)
                    count = delQuick(self & struct('hash',items{i}{1}), true);
                    assert(count == 0);
                    self.spec.remove_object(items{i}{2});
                end
            end
        end
    end
end
function folded_array = subfold(name, folds)
    folded_array = arrayfun(@(len,idx,s) name(s-len+1:s), folds, 1:length(folds), cumsum(folds), 'UniformOutput', false);
end
function config = buildConfig(config, validation_config, store_name)
    function validateInput(address, target)
        for k=1:numel(fieldnames(target))
            fn = fieldnames(target);
            address{end+1} = '.';
            address{end+1} = fn{k};
            if ~isstruct(target.(fn{k}))
                subscript = substruct(address{:});
                try
                    value = subsref(config, subscript);
                    vconfig = subsref(validation_config, subscript);
                    type_check = vconfig.type_check;
                    if ~type_check(value)
                        % Throw error for config that fails type validation
                        error('DataJoint:StoreConfig:WrongType', ...
                            'Unexpected type `%s` for config `%s` in store `%s`. Expecting `%s`.', class(value), strjoin(address, ''), store_name, char(type_check));
                    end
                catch ME
                    if strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Throw error for extra config
                        error('DataJoint:StoreConfig:ExtraConfig', ...
                            'Unexpected additional config `%s` specified in store `%s`.', strjoin(address, ''), store_name);
                    else
                        rethrow(ME);
                    end
                end
            else
                validateInput(address, target.(fn{k}));
            end
            address(end) = [];
            address(end) = [];
        end
    end
    function validateConfig(address, target)
        for k=1:numel(fieldnames(target))
            fn = fieldnames(target);
            address{end+1} = '.';
            address{end+1} = fn{k};
            if any(strcmp('required',fieldnames(target)))
                address(end) = [];
                address(end) = [];
                subscript = substruct(address{:});
                vconfig = subsref(validation_config, subscript);
                required = vconfig.required;
                try
                    value = subsref(config, subscript);
                catch ME
                    if required && strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Throw error for required config
                        error('DataJoint:StoreConfig:MissingRequired', ...
                            'Missing required config `%s` in store `%s`.', strjoin(address, ''), store_name);
                    elseif strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Set default for optional config
                        default = vconfig.default;
                        config = subsasgn(config, subscript, default);
                    end
                end
                break;
            else
                validateConfig(address, target.(fn{k}));
            end
            address(end) = [];
            address(end) = [];
        end
    end
    validateInput({}, config);
    validateConfig({}, validation_config);
end