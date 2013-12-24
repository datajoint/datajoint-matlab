classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId       % connection handle
        packages     % maps database names to package names
        
        % dependency lookups by table name
        children     % maps table names to their children table names   (primary foreign key)
        parents      % maps table names to their parent table names     (primary foreign key)
        references   % maps table names to their refenced tables    (non-primary foreign key)
        referencing  % maps table names to their referencing tables (non-primary foreign key)
    end
    
    properties(Access = private)
        password
    end
    
    properties(Dependent)
        isConnected
    end
    
    methods
        
        function self=Connection(host, username, password, initQuery)
            % specify the connection to the database.
            % initQuery is the SQL query to be executed at the start
            % of each new session.
            try
                mymVersion = mym('version');
                assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6)
            catch
                error('Outdated version of mYm.  Please upgrade to version 2.6 or later')
            end
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
            self.children    = containers.Map('KeyType','char','ValueType','any');
            self.parents     = containers.Map('KeyType','char','ValueType','any');
            self.references  = containers.Map('KeyType','char','ValueType','any');
            self.referencing = containers.Map('KeyType','char','ValueType','any');
            self.packages = containers.Map;
        end
        
        
        
        function addPackage(self, dbname, package)
            self.packages(dbname) = package;
        end
        
        
        function loadDependencies(self, schema)
            % load dependencies from SHOW CREATE TABLE
            pat = cat(2,...
                'FOREIGN KEY\s+\((?<attrs1>[`\w, ]+)\)\s+',...  % attrs1
                'REFERENCES\s+(?<ref>[^\s]+)\s+',...        % referenced table name
                '\((?<attrs2>[`\w, ]+)\)');
            
            for tabName = schema.headers.keys
                s = self.query(sprintf('SHOW CREATE TABLE `%s`.`%s`', schema.dbname, tabName{1}));
                s = strtrim(regexp(s.('Create Table'){1},'\n','split')');
                s = regexp(s,pat,'names');
                for s=[s{~cellfun(@isempty,s)}]
                    assert(isequal(s.attrs1,s.attrs2),...
                        'Foreign keys must link identically named attributes')
                    s.attrs = strsplit(s.attrs1,', ');
                    s.attrs = cellfun(@(s) s(2:end-1), s.attrs, 'uni',false);
                    isPrimary = all(ismember(s.attrs,schema.headers(tabName{1}).primaryKey));
                    from = sprintf('`%s`.`%s`',schema.dbname,tabName{1});
                    if isempty(regexp(s.ref,'`\.`','once'))
                        s.ref = sprintf('`%s`.%s',schema.dbname,s.ref);
                    end
                    if isPrimary
                        addMember(self.parents, from, s.ref)
                        addMember(self.children, s.ref, from)
                    else
                        addMember(self.references, from, s.ref)
                        addMember(self.referencing, s.ref, from)
                    end
                end
            end
        end
                
        
        function className = getPackage(self, className, strict)
            % convert '$database_name.ClassName' to 'package.ClassName'
            % If strict, then throw an error if the database_name was not found.
            strict = nargin>=3 && strict;
            if className(1)=='$'
                [schemaName,className] = strtok(className,'.');
                
                if self.packages.isKey(schemaName(2:end))
                    schemaName = self.packages(schemaName(2:end));
                elseif strict
                    error('Unknown package for "%s%s". Activate its schema first.', ...
                        schemaName(2:end), className)
                end
                className = [schemaName className];
            end
        end
        
        
        
        function reload(self)
            % reload all schemas
            schemas = self.packages.values;
            for s=schemas(:)'
                reload(feval([s{1} '.getSchema']))
            end
        end
        
        
        
        function ret = get.isConnected(self)
            ret = ~isempty(self.connId) && 0==mym(self.connId, 'status');
            
            if ~ret && self.inTransaction
                if dj.set('reconnectTimedoutTransaction')
                    dj.assert(false, '!disconnectedTransaction:Reconnected after server disconnected during a transaction')
                else
                    dj.assert(false, 'disconnectedTransaction:Server disconnected during a transaction')
                end
            end
        end
        
        
        
        function ret = query(self, queryStr, varargin)
            % dj.Connection/query - query(connection, queryStr, varargin) issue an
            % SQL query and return the result if any.
            % The same connection is re-used by all DataJoint objects.
            if ~self.isConnected
                self.connId=mym('open', self.host, self.user, self.password);
                if ~isempty(self.initQuery)
                    self.query(self.initQuery);
                end
            end
            if nargout>0
                ret=mym(self.connId, queryStr, varargin{:});
            else
                mym(self.connId, queryStr, varargin{:});
            end
        end
        
        
        
        function startTransaction(self)
            self.query('START TRANSACTION WITH CONSISTENT SNAPSHOT')
            self.inTransaction = true;
        end
        
        
        
        function commitTransaction(self)
            assert(self.inTransaction, 'No transaction to commit')
            self.query('COMMIT')
            self.inTransaction = false;
        end
        
        
        
        function cancelTransaction(self)
            self.inTransaction = false;
            self.query('ROLLBACK')
        end
        
        
        
        function close(self)
            if self.isConnected
                fprintf('closing DataJoint connection #%d\n', self.connId)
                mym(self.connId, 'close')
            end
            self.inTransaction = false;
        end
        
        
        function delete(self)
            self.close
        end
        
    end
end


function addMember(map,key,value)
if ~map.isKey(key)
    map(key) = {};
end
map(key) = [map(key) {value}]; %#ok<NASGU>
end