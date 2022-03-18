%{
duty_date:  date
----- 
(duty_first)    -> TestLab.User(user_id)
(duty_second)    -> TestLab.User(user_id)
(duty_third)    -> TestLab.User(user_id)
%}

classdef Duty < dj.Manual
end