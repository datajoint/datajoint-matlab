%{
tp.PsySession (manual) # Populated by the stim program
psy_id          : smallint unsigned     # unique psy session number
---
-> tp.Animal
distance_to_display     : float      # (cm) eye-to-monitor distance
display_width           : float      # (cm) 
display_height          : float      # (cm) 
psy_ts=CURRENT_TIMESTAMP: timestamp  # automatic
%}


classdef PsySession < dj.Relvar
    properties(Constant)
        table = dj.Table('tp.PsySession')
    end
    methods
        function self = PsySession(varargin)
            self.restrict(varargin)
        end
    end
end