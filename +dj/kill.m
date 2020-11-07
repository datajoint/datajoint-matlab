% Show MySQL all connections and prompt to kill a connection.
%   dj.kill() lists all connections and prompts the user to enter an id to
%   kill.
%   
%   dj.kill(restriction) lists all connections satisfying the specified
%   restriction. Restrictions are specified as strings and can involve any
%   of the attributes of information_schema.processlist: ID, USER, HOST,
%   DB, COMMAND, TIME, STATE, INFO.
%
%   dj.kill(restriction, connection) allows specifying the target connection.
%   will use default connection (dj.conn) if not specified.
%
%   dj.kill(restriction, connection, order_by) allows providing an order_by
%   argument. By default, output is lited by ID in ascending order.
%
%   Examples:
%       dj.kill('HOST LIKE "%at-compute%"') lists only connections from
%       at-compute.
%
%       dj.kill('TIME > 600') lists only connections older than 10 minutes.
%
%       dj.kill('', dj.conn, 'time') will display no restrictions for the 
%         default connection ordered by TIME.
%


function kill(restriction, connection, order_by)

    if nargin < 3
        order_by = {};
    end

    if nargin < 2
        connection = dj.conn;
    end

    qstr = 'SELECT * FROM information_schema.processlist WHERE id <> CONNECTION_ID()';

    if nargin && ~isempty(restriction)
        qstr = sprintf('%s AND (%s)', qstr, restriction);
    end

    if isempty(order_by)
        qstr = sprintf('%s ORDER BY id', qstr);
    else
        if iscell(order_by)
            qstr = sprintf('%s ORDER BY %s', qstr, strjoin(order_by, ','));
        else
            qstr = sprintf('%s ORDER BY %s', qstr, order_by);
        end
    end

    while true
        query(connection, qstr)
        id = input('process to kill (''q''-quit, ''a''-all) > ', 's');
        if ischar(id) && strncmpi(id, 'q', 1)
            break
        elseif ischar(id) && strncmpi(id, 'a', 1)
            res = query(connection, qstr);

            res = cell2struct(struct2cell(res), lower(fieldnames(res)));

            id = double(res.id)';
            for i = id
                query(connection, 'kill {Si}', i)
            end
            break
        end
        id = sscanf(id,'%d');
        if ~isempty(id) 
            query(connection, 'kill {Si}', id(1))
        end
    end

end
