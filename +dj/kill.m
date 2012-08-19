function kill
% DJ.KILL - show MySQL processes and connections and prompt to kill a
% connection.

query(dj.conn, 'show processlist')
id = input('process to kill>');
if ~isempty(id) && isnumeric(id) 
    query(dj.conn, 'kill {Si}', id(1))
end
query(dj.conn, 'show processlist')
