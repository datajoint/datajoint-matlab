%{
tp.Sync (imported) # stimulus synchronization
-> tp.Scan
-----
-> tp.PsySession
first_trial : int   # first trial matching scan 
last_trial  : int   # last trial matching scan
frame_times : longblob   # scan's frame times on stimulus clock
%}

classdef Sync < dj.Relvar & dj.AutoPopulate

	properties(Constant)
		table = dj.Table('tp.Sync')
	end
	properties
		popRel = tp.Scan 
	end

	methods
		function self = Sync(varargin)
			self.restrict(varargin)
		end

		function makeTuples(self, key)
		%!!! compute missing fields for key here
			self.insert(key)
		end
	end
end
