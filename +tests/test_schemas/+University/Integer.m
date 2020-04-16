%{
id      : int   
---
int_nodef_nonull_nounq              : int
int_nulldef_nonull_nounq=null       : int
int_cordef_nonull_nounq=4           : int
int_nodef_null_nounq                : int null
int_nulldef_null_nounq=null         : int null
int_cordef_null_nounq=4             : int null
int_nodef_nonull_unq                : int
int_nulldef_nonull_unq=null         : int
int_cordef_nonull_unq=4             : int
int_nodef_null_unq                  : int null
int_nulldef_null_unq=null           : int null
int_cordef_null_unq=4               : int null
unique index (int_nodef_nonull_unq)
unique index (int_nulldef_nonull_unq)
unique index (int_cordef_nonull_unq)
unique index (int_nodef_null_unq)
unique index (int_nulldef_null_unq)
unique index (int_cordef_null_unq)
%}
classdef Integer < dj.Manual
end