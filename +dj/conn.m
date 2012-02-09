function connObj = conn(host, user, pass, initQuery)
% dj.conn - construct and return a persistent dj.Connection object.
%
% Only one connection should be open at a time and all DataJoint classes
% call dj.conn to get the connection object.
%
% The first time dj.conn is called, it must establish a conection. The
% connection parameters may be specified by input arguments. Any omitted 
% paramters are taken from the environment variables DJ_HOST, DJ_USER, DJ_PASS, 
% and DJ_INIT are used. Finally, if the required parameters are still missing, 
% the user is prompted to enter them manually.
%
% The last parameter, initQuery (or the environemnt variable) DJ_INIT specify 
% the query to be executed everytime a new connection session is established. 
%
% Once established during the first invocation, the connection object cannot 
% be changed. To reset the connection, use 'clear functions' or 'clear classes'.

persistent CONN_OBJ

% disconnect if the host or the user have changed
if nargin>0 && isa(CONN_OBJ, 'dj.Connection')
    if ~strcmp(host, CONN_OBJ.host) || ~strcmp(user, CONN_OBJ.user)
        CONN_OBJ.close
    end
    if ~CONN_OBJ.isConnected
        CONN_OBJ = '';
    end
end

if isempty(CONN_OBJ)
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
        pass = input('Enter datajoint password >','s');
    end
    
    % get initial query (if any) to execute when a connection is (re)established
    if nargin<4 || isempty(initQuery)
        initQuery = getenv(env.init);
    end
    
    CONN_OBJ = dj.Connection(host, user, pass, initQuery);
end

connObj = CONN_OBJ;

if ~connObj.isConnected
    query(connObj, 'status')
end

if nargout==0
    query(connObj, 'SELECT connection_id()')
end