%{
# Document
document_id : int   
---
document_name : varchar(30)
document_data1  : attach
document_data2  : attach@main
document_data3  : filepath@main
%}
classdef Document < dj.Manual
end 