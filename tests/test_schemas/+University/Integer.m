%{
id      : int   
---
int_nodef_nounq                 : int
int_nulldef_nounq=null          : int
int_cordef1_nounq=4             : int
#int_wrgdef_nounq="hi"          : int
int_nodef_unq                   : int
int_nulldef_unq=null            : int
int_cordef1_unq=4               : int
#int_wrgdef_unq="hi"            : int
unique index (int_nodef_unq)
unique index (int_nulldef_unq)
unique index (int_cordef1_unq)
#unique index (int_wrgdef_unq)
%}
classdef Integer < dj.Manual
end