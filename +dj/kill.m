% dj.kill - show MySQL all connections and prompt to kill a connection.

function kill
while true
    query(dj.conn, 'show processlist')
    id = input('process to kill (''q''-quit) >','s');
    if ischar(id) && strncmpi(id,'q',1)
        break
    end
    id = sscanf(id,'%d');
    if ~isempty(id) 
        query(dj.conn, 'kill {Si}', id(1))
    end
end