%{
# Subject
subject_id : int  # {subject_id} Comment to test curly bracket
---
subject_dob : date
unique index(subject_dob)
%}
classdef Subject < dj.Manual
end 