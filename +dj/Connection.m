classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId        % connection handle
        packageDict = containers.Map    % Map database names to package names
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
                dj.assert(mymVersion.major > 2 || mymVersion.major==2 && mym.Version.minor>=6)
            catch
                dj.assert(false,'Outdated version of mYm.  Please upgrade to version 2.6 or later')
            end
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
        end
        
        
        
        function addPackage(self, dbname, package)
            self.packageDict(dbname) = package;
        end
        
        
        
        function className = getPackage(self, className, strict)
            % convert '$database_name.ClassName' to 'package.ClassName'
            % If strict, then throw an error if the database_name was not found.
            strict = nargin>=3 && strict;
            if className(1)=='$'
                [schemaName,className] = strtok(className,'.');
                
                if self.packageDict.isKey(schemaName(2:end))
                    schemaName = self.packageDict(schemaName(2:end));
                elseif strict
                    error('Unknown package for "%s%s". Activate its schema first.', ...
                        schemaName(2:end), className)
                end
                className = [schemaName className];
            end
        end
        
        
        
        function reload(self)
            % reload all schemas
            schemas = self.packageDict.values;
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
        
    end
end
