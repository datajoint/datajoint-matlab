classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId        % connection handle
        packageDict = struct  % maps database schemas to matlab packages
    end
    
    properties(Access = public)
        reconnectTransaction = true   % if true, reconnect to the server even within a transaction. 
                                      % set false to guarantee transaction automicity
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
            
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
        end
        
        
        
        function addPackage(self, dbname, package)
            self.packageDict.(dbname) = package;
        end
        
        
        
        function name = getPackage(self, name, strict)
            % replaces the schema name with its package name iff necessary
            strict = nargin<3 || strict;
            if iscellstr(name)
                name = cellfun(@(x) self.getPackage(x, strict), name, 'uni', false);
            elseif all(name~='.') || name(1)=='$'
                s = regexp(name, '^\$?(\w+)','tokens');
                assert(length(s)==1, 'invalid schema name in "%s"', name)
                try
                    name = regexprep(name, '^(\$?\w+)',self.packageDict.(s{1}{1}));
                catch err   %#ok
                    if strict
                        error('Unknown package in "%s". Activate the schema first.', name)
                    end
                end
            end
        end
        
        
        
        function reload(self)
            % reload all schemas
            schemaNames = struct2cell(self.packageDict);
            for i=1:length(schemaNames)
                reload(eval([schemaNames{i} '.getSchema']))
            end
        end
        
        
        
        function ret = get.isConnected(self)
            ret = ~isempty(self.connId) && 0==mym(self.connId, 'status');
            
            if ~ret && self.inTransaction
                if self.reconnectTransaction
                    warning('DataJoint:TransactionReconnect', 'reconnecting after server disconnected during a transaction')
                else
                    throwAsCaller(MException('DataJoint:TransactionReconnect', 'server disconnected during a transaction'))
                end
            end
        end
        
        
        
        function ret = query(self, queryStr, varargin)
            % dj.Schema/query - query(dbname, queryStr, varargin) issue an
            % SQL query and return the result if any.
            % Reuses the same connection, which limits connections to one
            % database server at a time, but multiple schemas are okay.
            %}
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