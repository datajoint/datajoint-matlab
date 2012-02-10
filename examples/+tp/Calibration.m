%{
tp.Calibration (manual)  # Basic subject info
cal_id        : int      # unique calibration id, never re-used
---
setup          : enum('ATolias 1', 'ATolias 2')   # room
objective_lens : enum('10x','16x','20x','25x','40x')  # objective lens
fov            : float          # (um) calibrated scanimage field of view at mag=1.0
cal_date       : date           # YYYY-MM-DD when power, FOV, and PSF cals were done
cal_notes      : varchar(4095)  # laser notes, mirror size, etc.
%}



classdef Calibration < dj.Relvar
    
    properties(Constant)
        table = dj.Table('tp.Calibration')
    end
    
    methods
        function self = Calibration(varargin)
            self.restrict(varargin)
        end
    end
end