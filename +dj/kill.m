% dj.kill - show MySQL all connections and prompt to kill a connection.

function kill(restriction)

qstr = 'SELECT * FROM information_schema.processlist WHERE id <> CONNECTION_ID()';
if nargin && ~isempty(restriction)
    qstr = sprintf('%s AND %s', qstr, restriction);
end
    
while true
    query(dj.conn, qstr)
    id = input('process to kill (''q''-quit, ''a''-all) > ', 's');
    if ischar(id) && strncmpi(id, 'q', 1)
        break
    elseif ischar(id) && strncmpi(id, 'a', 1)
        res = query(dj.conn, qstr);
        id = double(res.ID)';
        for i = id
            query(dj.conn, 'kill {Si}', i)
        end
        break
    end
    id = sscanf(id,'%d');
    if ~isempty(id) 
        query(dj.conn, 'kill {Si}', id(1))
    end
end
