%{
tp.Scan (imported) # scanimage scan info
->tp.Session
scan_idx : smallint # scanimage-generated sequential number
-----
mag     : float    # magnification
fps     : double   # frames per second
height  : smallint  # pixel height
width   : smallint  # pixel width 
dx     : float  # (um) microns per pixel along x
dy     : float  # (um) microns per pixel along y
dz    : float    # (um) z-step (if stack), 0 otherwise
nframes : smallint # number of frames
%}

classdef Scan < dj.Relvar & dj.AutoPopulate

	properties(Constant)
		table = dj.Table('tp.Scan')
	end
	properties
		popRel = tp.Session
	end

	methods
		function self = Scan(varargin)
			self.restrict(varargin)
		end

		function makeTuples(self, key)
			self.insert(key)
		end
	end
end
