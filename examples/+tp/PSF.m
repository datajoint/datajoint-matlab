%{
tp.PSF (manual) # my newest table
-> tp.Calibration
psf_id : smallint  # point spread function number
-----
psf_mag   : float   # scanimage magnification
psf_dx : float   # (um) pixel pitch along x
psf_dy : float      # (um) pixel pitch along y
psf_dz : float        # (um) slice stap
bead_stack : longblob  # a stack taken around a bead
%}

classdef PSF < dj.Relvar
	properties(Constant)
		table = dj.Table('tp.PSF')
	end

	methods
		function self = PSF(varargin)
			self.restrict(varargin)
		end
	end
end