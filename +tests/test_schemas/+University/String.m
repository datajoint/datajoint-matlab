%{
id      : int   
---
string_nodef_nounq              : varchar(50)
string_nulldef_nounq=null       : varchar(50)
#string_cordef1_nounq=""           : varchar(50)
string_cordef2_nounq="hi"           : varchar(50)
#string_wrgdef_nounq=4           : varchar(50)
string_nodef_unq              : varchar(50)
string_nulldef_unq=null       : varchar(50)
#string_cordef1_unq=""           : varchar(50)
string_cordef2_unq="hi"           : varchar(50)
#string_wrgdef_unq=4           : varchar(50)
unique index (string_nodef_unq)
unique index (string_nulldef_unq)
#unique index (string_cordef1_unq)
unique index (string_cordef2_unq)
#unique index (string_wrgdef_unq)
%}
classdef String < dj.Manual
end