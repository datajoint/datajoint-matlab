function kill
% DJ.KILL - show MySQL processes and connections and prompt to kill a
% connection.

while true
    query(dj.conn, 'show processlist')
    id = input('process to kill>');
    if isempty(id) || ~isnumeric(id)
        break
    end
    query(dj.conn, 'kill {Si}', id(1))
end