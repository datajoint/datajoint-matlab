classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId       % connection handle
        packages     % maps database names to package names
        
        % dependency lookups by table name
        foreignKeys   % maps table names to their referenced table names     (primary foreign key)
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
            setupDJ(true);
            try
                mymVersion = mym('version');
                assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6)
            catch
                error 'Outdated version of mYm.  Please upgrade to version 2.6 or later'
            end
            if verLessThan('matlab', '8.6')
                error 'MATLAB version 8.6 (R2015b) or greater is required'
            end
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
            self.foreignKeys  = struct([]);
            self.packages = containers.Map;
        end
        
        
        function addPackage(self, dbname, package)
            self.packages(dbname) = package;
        end
        
        
        function loadDependencies(self, schema)
            % load dependencies from SHOW CREATE TABLE
            pat = cat(2,...
                'FOREIGN KEY\s+\((?<attrs>[`\w, ]+)\)\s+',...  % attrs1
                'REFERENCES\s+(?<ref>[^\s]+)\s+',...        % referenced table name
                '\((?<ref_attrs>[`\w, ]+)\)');
            
            for tabName = schema.headers.keys
                fk = self.query(sprintf('SHOW CREATE TABLE `%s`.`%s`', schema.dbname, tabName{1}));
                fk = strtrim(regexp(fk.('Create Table'){1},'\n','split')');
                fk = regexp(fk, pat, 'names');
                fk = [fk{:}];
                from = sprintf('`%s`.`%s`', schema.dbname, tabName{1});
                
                for s=fk
                    s.from = from;
                    s.ref = s.ref;
                    s.attrs = regexp(s.attrs, '\w+', 'match');
                    s.ref_attrs = regexp(s.ref_attrs, '\w+', 'match');
                    s.primary = all(ismember(s.attrs, schema.headers(tabName{1}).primaryKey));
                    s.multi = ~all(ismember(schema.headers(tabName{1}).primaryKey, s.attrs));
                    if isempty(regexp(s.ref,'`\.`','once'))
                        s.ref = sprintf('`%s`.%s',schema.dbname,s.ref);
                    end
                    s.aliased = ~isequal(s.attrs, s.ref_attrs);
                    self.foreignKeys = [self.foreignKeys, s];
                end
            end
        end
        
        
        function [names, isprimary] = parents(self, child, primary)
            if isempty(self.foreignKeys)
                names = {};
                isprimary = [];
            else
                ix = strcmp(child, {self.foreignKeys.from});
                if nargin>2
                    ix = ix & primary == [self.foreignKeys.primary];
                end
                names = {self.foreignKeys(ix).ref};
                if nargout > 1
                    isprimary = [self.foreignKeys(ix).primary];
                end
            end
        end
        
        
        function [names, isprimary] = children(self, parent, primary)
            if isempty(self.foreignKeys)
                names = {};
                isprimary = [];
            else
                ix = strcmp(parent, {self.foreignKeys.ref});
                if nargin>2
                    ix = ix & primary == [self.foreignKeys.primary];
                end
                names = {self.foreignKeys(ix).from};
                if nargout > 1
                    isprimary = [self.foreignKeys(ix).primary];
                end
            end
        end
        
        
        function className = tableToClass(self, fullTableName, strict)
            % convert '`dbname`.`table_name`' to 'package.ClassName'
            % If strict (false by default), throw error if the dbname is not found.
            % If not strict and the name is not found, then className=tableName
            
            strict = nargin>=3 && strict;
            s = regexp(fullTableName, '^`(?<dbname>.+)`.`(?<tablename>[#~\w\d]+)`$','names');
            className = fullTableName;
            if ~isempty(s) && self.packages.isKey(s.dbname)
                className = sprintf('%s.%s',self.packages(s.dbname),dj.internal.toCamelCase(s.tablename));
            elseif strict
                error('Unknown package for "%s". Activate its schema first.', fullTableName)
            end
        end
                
        
        function reload(self)
            % reload all schemas
            self.clearDependencies
            for s=self.packages.values
                reload(feval([s{1} '.getSchema']))
            end
        end
        
        
        function ret = get.isConnected(self)
            ret = ~isempty(self.connId) && 0==mym(self.connId, 'status');
            
            if ~ret && self.inTransaction
                if dj.set('reconnectTimedoutTransaction')
                    warning 'Reconnected after server disconnected during a transaction'
                else
                    error 'Server disconnected during a transaction'
                end
            end
       end
        
        
        function ret = query(self, queryStr, varargin)
            % dj.Connection/query - query(connection, queryStr, varargin) issue an
            % SQL query and return the result if any.
            % The same connection is re-used by all DataJoint objects.
            if ~self.isConnected
                self.connId=mym(-1, 'open', self.host, self.user, self.password);
                if ~isempty(self.initQuery)
                    self.query(self.initQuery);
                end
            end
            v = varargin;
            if dj.set('bigint_to_double')
                v{end+1} = 'bigint_to_double';
            end
            if nargout>0
                ret=mym(self.connId, queryStr, v{:});
            else
                mym(self.connId, queryStr, v{:});
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
            self.clearDependencies
            self.close
        end
        
        
        function clearDependencies(self, schema)
            if nargin<2
                % remove all if the schema is not specified
                self.foreignKeys = struct([]);
            elseif ~isempty(self.foreignKeys)
                % remove references from the given schema
                % self.referenced.remove
                tableNames = cellfun(@(s) ...
                    sprintf('`%s`.`%s`', schema.dbname, s), ...
                    schema.tableNames.values, 'uni', false);
                self.foreignKeys(ismember({self.foreignKeys.from}, tableNames)) = [];
            end
        end
                
    end
end
