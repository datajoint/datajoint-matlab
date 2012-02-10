%{
tp.PsyOriCond (manual) # Populated by the stim program
->tp.PsySession
cond_idx        : smallint unsigned     # condition index
---
pre_blank=0       : float                  # (s) blank period preceding trials
post_blank=0      : float                  # (s) blank period following trials
luminance         : float                  # cd/m^2 mean
contrast          : float                  # Michelson contrast 0-1
grating           : enum('sqr','sin')      # sinusoidal or square
drift_fraction=0  : float                  # the fraction of the trial duration taken by drifting grating
spatial_freq      : float                  # cycles/degree
init_phase        : float                  # 0..1
trial_duration    : float                  # ms
temp_freq         : float                  # Hz
direction         : float                  # 0-360 degrees
%}


classdef PsyOriCond < dj.Relvar
    properties(Constant)
        table = dj.Table('tp.PsyOriCond')
    end
    
    methods
        function self = PsyOriCond(varargin)
            self.restrict(varargin)
        end
    end
end