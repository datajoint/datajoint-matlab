%{
schedule:   varchar(32)
---
(monday_on_call) -> Company.Employee(employee_id)
%}
classdef Duty < dj.Manual
end
