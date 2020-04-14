%{
segmentation_method: varchar(16) # ‘cnmf’
seg_parameter_set_id: int # 1
subject_fullname: varchar(64)  #‘lpinto_SP6’
session_date: date
session_number: int
fov: int
---
num_chunks: int
cross_chunks_x_shifts: blob
cross_chunks_y_shifts: blob
cross_chunks_reference_image: blob@mesoimaging
%}
classdef Debug < dj.Manual
end