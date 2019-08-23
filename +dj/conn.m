% dj.conn - constructs and returns a persistent dj.Connection object.
%
% This function can be used in cases when all datajoint schemas connect to
% the same database server with the same credentials.  If this is not so,
% you may wish to create multiple functions patterned after dj.conn to
% manage multiple persistent connections.
%
% The first time dj.conn is called, it must establish a conection. The
% connection parameters may be specified by input arguments. Any values omitted
% from the input arguments will be taken from the environment variables
% DJ_HOST, DJ_USER, DJ_PASS, and DJ_INIT are used.
% Finally, if the required parameters are still missing, dj.conn will prompt the
% user to enter them manually.
%
% The last parameter, initQuery (or the environemnt variable DJ_INIT) specify
% the query to be executed everytime a new connection session is established.
%
% Once established during the first invocation, the connection object cannot
% be changed. To reset the connection, use 'clear functions' or 'clear classes'.

function connObj = conn(host, user, pass, initQuery, reset, use_tls, nogui)
persistent CONN

if nargin < 5 || isempty(reset)
    reset = false;
end

% get password prompt option
if nargin < 7 || isempty(nogui)
    nogui = false;
end


if isa(CONN, 'dj.Connection') && ~reset
    if nargin>0
        if strcmp(CONN.host,host)
            warning('DataJoint:Connection:AlreadyInstantiated', sprintf([...
                'Connection already instantiated.\n' ...
                'Will use existing connection to "' CONN.host '".\n' ...
                'To reconnect, set reset to true']));
        else
            error('DataJoint:Connection:AlreadyInstantiated', sprintf([...
                'Connection already instantiated to "' CONN.host '".\n' ...
                'To reconnect, set reset to true']));
        end
    end
else
    % invoke setupDJ
    % optional environment variables specifying the connection.
    env  = struct(...
        'host', 'DJ_HOST', ...
        'user', 'DJ_USER', ...
        'pass', 'DJ_PASS', ...
        'init', 'DJ_INIT');
    
    % get host address
    if nargin<1 || isempty(host)
        host = getenv(env.host);
    end
    if isempty(host)
        host = input('Enter datajoint host address> ','s');
    end
    
    % get username
    if nargin<2 || isempty(user)
        user = getenv(env.user);
    end
    if isempty(user)
        user = input('Enter datajoint username> ', 's');
    end
    
    % get password
    if nargin<3 || isempty(pass)
        pass = getenv(env.pass);
    end
    if isempty(pass)
        if nogui
            pass = input('Enter datajoint password> ','s');
        else
            pass = dj.lib.getpass('Enter datajoint password');
        end
    end
    
    % get initial query (if any) to execute when a connection is (re)established
    if nargin<4 || isempty(initQuery)
        initQuery = getenv(env.init);
    end

    % get tls option
    if nargin<6 || isempty(use_tls)
        use_tls = dj.set('use_tls');
    end
    
    if islogical(use_tls) && ~use_tls
        use_tls = 'false';
    elseif islogical(use_tls) && use_tls
        use_tls = 'true';
    elseif ~isstruct(use_tls)
        use_tls = 'none';
    else
        use_tls = jsonencode(use_tls);
    end
    
    CONN = dj.Connection(host, user, pass, initQuery, use_tls);
end

connObj = CONN;

% if connection fails to establish, remove the persistent connection object
if ~connObj.isConnected
    try
        query(connObj, 'status')
    catch e
        CONN = [];
        rethrow(e) 
    end
end

if nargout==0
    query(connObj, 'SELECT connection_id()')
end