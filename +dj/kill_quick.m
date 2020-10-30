% Kill database connections without prompting.
%   dj.kill_quick() kills MySQL server connections matching 'restriction',
%   returning the number of terminated connections.
%
%   Restrictions are specified as strings and can involve any of the attributes
%   of information_schema.processlist: ID, USER, HOST, DB, COMMAND, TIME,
%   STATE, INFO.
%
%   Examples:
%       dj.kill_quick('HOST LIKE "%compute%"') terminates connections from hosts
%       containing "compute" in their hostname.
%
%       dj.kill_quick('TIME > 600') terminates all connections older than 10
%       minutes.

function nkill = kill_quick(restriction, connection)

    if nargin < 2
        connection = dj.conn;
    end

    qstr = 'SELECT * FROM information_schema.processlist WHERE id <> CONNECTION_ID()';

    if nargin && ~isempty(restriction)
        qstr = sprintf('%s AND (%s)', qstr, restriction);
    end

    res = query(connection, qstr);

    if isfield(res, 'ID')  % MySQL >8.x variation
        id_field = 'ID';
    else
        id_field = 'id';
    end

    nkill = 0;
    for id = double(res.(id_field))'
        query(connection, 'kill {Si}', id);
        nkill = nkill + 1;
    end
end
