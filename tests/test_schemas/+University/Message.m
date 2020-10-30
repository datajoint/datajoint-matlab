%{
# Message
msg_id : uuid       # test comment?
---
body : varchar(30)
dep_id=null : uuid
%}
classdef Message < dj.Manual
end