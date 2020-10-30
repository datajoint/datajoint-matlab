% dj.internal.ExternalTable - The table tracking externally stored objects.
%   Declare as dj.internal.ExternalTable(connection, store, schema)
classdef ExternalTable < dj.Relvar
    properties (Hidden, Constant)
        BACKWARD_SUPPORT_DJPY012 = true
    end
    properties
        store
        spec
        cache_folder
    end
    properties (Hidden)
        connection
    end
    methods
        function self = ExternalTable(connection, store, schema)
            % construct table using config validation criteria supplied by store plugin
            self.store = store;
            self.schema = schema;
            self.connection = connection;
            stores = dj.config('stores');
            assert(isstruct(stores.(store)), 'Store `%s` not configured as struct.', store);
            assert(any(strcmp('protocol', fieldnames(stores.(store)))), ...
                'Store `%s` missing `protocol` key.', store);
            if isstring(stores.(store).protocol)
                storePlugin = char(stores.(store).protocol);
            else
                assert(ischar(stores.(store).protocol), ...
                    ['Store `%s` set `protocol` as `%s` but ' ...
                    'expecting `char||string`.'], store, ...
                    class(stores.(store).protocol));
                storePlugin = stores.(store).protocol;
            end
            
            storePlugin(1) = upper(storePlugin(1));
            try
                config = buildConfig(stores.(store), ...
                    dj.store_plugins.(storePlugin).validation_config, store);
            catch ME
                if strcmp(ME.identifier,'MATLAB:undefinedVarOrClass')
                    % Throw error if plugin not found
                    error('DataJoint:StorePlugin:Missing', ...
                        'Missing store plugin `%s`.', storePlugin);
                elseif dj.internal.ExternalTable.BACKWARD_SUPPORT_DJPY012 && contains(...
                        ME.identifier,'DataJoint:StoreConfig')
                    config = buildConfig(stores.(store), ...
                        dj.store_plugins.(storePlugin).backward_validation_config, store);
                else
                    rethrow(ME);
                end
            end
            self.spec = dj.store_plugins.(storePlugin)(config);
            try
                self.cache_folder = strrep(dj.config('blobCache'), '\', '/');
            catch ME
                if strcmp(ME.identifier,'DataJoint:Config:InvalidKey')
                    self.cache_folder = [];
                else
                    rethrow(ME);
                end
            end
            if dj.internal.ExternalTable.BACKWARD_SUPPORT_DJPY012 && isempty(self.cache_folder)
                try
                    self.cache_folder = strrep(dj.config('cache'), '\', '/');
                catch ME
                    if strcmp(ME.identifier,'DataJoint:Config:InvalidKey')
                        self.cache_folder = [];
                    else
                        rethrow(ME);
                    end
                end
            end
            if ~isempty(self.cache_folder)
                assert(exist(self.cache_folder, 'dir')==7, 'Cache folder `%s` not found.', ...
                    self.cache_folder);
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
            % create external path based on the uuid hash
            uuid = strrep(uuid, '-', '');
            uuid_path = self.spec.make_external_filepath([self.schema.dbname subfold(...
                uuid, self.spec.type_config.subfolding) '/' uuid suffix]);
        end
        % -- BLOBS --
        function uuid = upload_buffer(self, blob)
            % put blob
            packed_cell = mym('serialize {M}', blob);
            % https://www.mathworks.com/matlabcentral/fileexchange/25921-getmd5
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            self.spec.upload_buffer(packed_cell{1}, self.make_uuid_path(uuid, ''));
            %  insert tracking info
            sql = sprintf(['INSERT INTO %s (hash, size) VALUES (X''%s'', %i) ON ' ...
                'DUPLICATE KEY UPDATE timestamp=CURRENT_TIMESTAMP'], self.fullTableName, ...
                uuid, length(packed_cell{1}));
            self.connection.query(sql);
        end
        function blob = download_buffer(self, uuid)
            % get blob via uuid (with caching support)
            blob = [];
            if ~isempty(self.cache_folder)
                cache_path = [self.cache_folder '/' self.schema.dbname subfold(...
                    uuid, self.spec.type_config.subfolding) '/' uuid ''];
                try
                    fileID = fopen(cache_path, 'r');
                    result = fread(fileID);
                    fclose(fileID);
                    blob = mym('deserialize', uint8(result));
                catch
                end
            end
            if isempty(blob)
                blob_binary = uint8(self.spec.download_buffer(self.make_uuid_path(uuid, '')));
                blob = mym('deserialize', blob_binary);
                if ~isempty(self.cache_folder)
                    [~,start_idx,~] = regexp(cache_path, '/', 'match', 'start', 'end');
                    mkdir(cache_path(1:(start_idx(end)-1)));
                    fileID = fopen(cache_path, 'w');
                    fwrite(fileID, blob_binary);
                    fclose(fileID);
                end
            end
        end
        % -- UTILITIES --
        function refs = references(self)
            % generator of referencing table names and their referencing columns
            sql = {...
            'SELECT concat(''`'', table_schema, ''`.`'', table_name, ''`'') as referencing_table, column_name '
            'FROM information_schema.key_column_usage '
            'WHERE referenced_table_name="{S}" and referenced_table_schema="{S}"'
            };
            sql = sprintf('%s',sql{:});
            refs = self.connection.query(sql, self.plainTableName, self.schema.dbname);
        end
        function paths = fetch_external_paths(self, varargin)
            % generate complete external filepaths from the query.
            % Each element is a cell: {uuid, path}
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
        function unused = unused(self)
            % query expression for unused hashes
            ref = self.references;
            query = strjoin(cellfun(@(column, table) sprintf(...
                'hex(`hash`) in (select hex(`%s`) from %s)', column, table), ...
                ref.column_name, ref.referencing_table, 'UniformOutput', false), ' OR ');
            if ~isempty(query)
                unused = self - query;
            else
                unused = self;
            end
        end
        function used = used(self)
            % query expression for used hashes
            used = self - self.unused.proj();
        end        
        function delete(self, delete_external_files, limit)
            % DELETE(self, delete_external_files, limit)  
            %   Remove external tracking table records and optionally remove from ext storage
            %   self:                   <dj.internal.ExternalTable> Store Table instance.
            %   delete_external_files:  <boolean>  Remove from external storage.
            %   limit:                  <number> Limit the number of external objects to remove
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
function folded_path = subfold(name, folds)
    % subfolding for external storage:   e.g.  subfold('aBCdefg', [2, 3])  -->  {'ab','cde'}
    if ~isempty(folds)
        folded_array = arrayfun(@(len,idx,s) name(s-len+1:s), folds', 1:length(folds), ...
            cumsum(folds'), 'UniformOutput', false);
        folded_path = ['/' strjoin(folded_array, '/')];
    else
        folded_path = '';
    end
end
function config = buildConfig(config, validation_config, store_name)
    % builds out store config with defaults set
    function validateInput(address, target)
        % validates supplied config
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
                            ['Unexpected type `%s` for config `%s` in store `%s`. ' ...
                            'Expecting `%s`.'], class(value), strjoin(address, ''), ...
                            store_name, char(type_check));
                    end
                catch ME
                    if strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Throw error for extra config
                        error('DataJoint:StoreConfig:ExtraConfig', ...
                            'Unexpected additional config `%s` specified in store `%s`.', ...
                            strjoin(address, ''), store_name);
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
        % verifies if input contains all expected config
        for k=1:numel(fieldnames(target))
            fn = fieldnames(target);
            address{end+1} = '.';
            address{end+1} = fn{k};
            if any(strcmp('mode',fieldnames(target)))
                address(end) = [];
                address(end) = [];
                subscript = substruct(address{:});
                vconfig = subsref(validation_config, subscript);
                mode = vconfig.mode;
                if any(strcmp('datajoint_type', fieldnames(config)))
                    mode_result = mode(config.datajoint_type);
                else
                    mode_result = mode('not_necessary');
                end
                try
                    value = subsref(config, subscript);
                catch ME
                    if mode_result==1 && strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Throw error for required config
                        error('DataJoint:StoreConfig:MissingRequired', ...
                            'Missing required config `%s` in store `%s`.', ...
                            strjoin(address, ''), store_name);
                    elseif mode_result==0 && strcmp(ME.identifier,'MATLAB:nonExistentField')
                        % Set default for optional config
                        default = vconfig.default;
                        config = subsasgn(config, subscript, default);
                    else
                        rethrow(ME);
                    end
                end
                if mode_result==-1
                    % Throw error for rejected config
                    error('DataJoint:StoreConfig:ExtraConfig', ...
                        'Incompatible additional config `%s` specified in store `%s`.', ...
                        strjoin(address, ''), store_name);
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