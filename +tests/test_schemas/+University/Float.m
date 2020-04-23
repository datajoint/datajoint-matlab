%{
id      : int   
---
float_nodef_nounq               : float
float_nulldef_nounq=null        : float
float_cordef1_nounq=1.2         : float
#float_wrgdef_nounq="hi"        : float
float_nodef_unq                 : float
float_nulldef_unq=null          : float
float_cordef1_unq=1.2           : float
#float_wrgdef_unq="hi"          : float
unique index (float_nodef_unq)
unique index (float_nulldef_unq)
unique index (float_cordef1_unq)
#unique index (float_wrgdef_unq)
%}
classdef Float < dj.Manual
end