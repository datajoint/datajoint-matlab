%{
id      : int   
---
date_nodef_nounq                    : date
date_nulldef_nounq=null             : date
#date_cordef1_nounq=""              : date
date_cordef2_nounq="2020-10-20"     : date
#date_wrgdef_nounq=4                : date
date_nodef_unq                      : date
date_nulldef_unq=null               : date
#date_cordef1_unq=""                : date
date_cordef2_unq="2020-10-20"       : date
#date_wrgdef_unq=4                  : date
unique index (date_nodef_unq)
unique index (date_nulldef_unq)
#unique index (date_cordef1_unq)
unique index (date_cordef2_unq)
#unique index (date_wrgdef_unq)
%}
classdef Date < dj.Manual
end