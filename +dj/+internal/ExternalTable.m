% dj.internal.External - an external static method class.
classdef ExternalTable < dj.internal.Table
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
            uuid_path = self.spec.make_external_filepath([self.schema.dbname '/' strjoin(subfold(uuid, self.spec.blob_config.subfolding), '/') '/' uuid suffix]);
        end
        function uuid = upload_buffer(self, blob)
            uuid = '1d751e2e1e74faf84ab485fde8ef72be';
            packed_cell = mym('serialize {M}', blob);
            self.spec.upload_buffer(packed_cell{1}, self.make_uuid_path(uuid, ''));
            %  insert tracking info
            sql = sprintf('INSERT INTO %s (hash, size) VALUES (X''%s'', %s) ON DUPLICATE KEY UPDATE timestamp=CURRENT_TIMESTAMP', self.fullTableName, uuid, length(packed_cell{1}));
            self.schema.conn.query(sql);
        end
        function blob = download_buffer(self, uuid)
            blob = mym('deserialize', uint8(self.spec.download_buffer(self.make_uuid_path(uuid, ''))));
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