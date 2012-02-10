%{
tp.Alignment (imported) # motion correction
-> tp.Scan
-----
raster_correction  : longblob   # raster artifact correction 
motion_correction  : longblob   # motion correction offsets
motion_max : float  # (um) max motion amplitude 
motion_rms : float  # (um) RMS of motion
green_img : longblob  # mean corrected image
red_img   : longblob  # mean corrected image
%}

classdef Alignment < dj.Relvar & dj.AutoPopulate

	properties(Constant)
		table = dj.Table('tp.Alignment')
	end
	properties
		popRel = tp.Scan
	end

	methods
		function self = Alignment(varargin)
			self.restrict(varargin)
		end

		function makeTuples(self, key)
			self.insert(key)
		end
	end
end
