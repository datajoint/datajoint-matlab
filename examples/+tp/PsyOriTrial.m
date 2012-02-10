%{
tp.PsyOriTrial (manual) # populated by the stim program
->tp.PsySession
trial_idx       : int     # trial index within sessions
---
->tp.PsyOriCond
flip_times        : mediumblob     # (s) row array of flip times
last_flip_count   : int unsigned   # the last flip number in this trial
%}



classdef PsyOriTrial < dj.Relvar
    properties(Constant)
        table = dj.Table('tp.PsyOriTrial')
    end
    methods
        function self = PsyOriTrial(varargin)
            self.restrict(varargin)
        end
    end
end