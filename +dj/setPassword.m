function setPassword(newPassword)
query(dj.conn, 'SET PASSWORD = PASSWORD("{S}")', newPassword)
disp done
end