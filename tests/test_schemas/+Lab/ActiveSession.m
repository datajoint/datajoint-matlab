%{
# ActiveSession
-> [unique] Lab.Subject
---
(session_rig_class, session_rig_id) -> [nullable, unique] Lab.Rig(rig_manufacturer, rig_model)
%}
classdef ActiveSession < dj.Manual
end 