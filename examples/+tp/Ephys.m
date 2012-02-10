%{
tp.Ephys (imported) # intracellular ephys loaded from external files
-> tp.Session
ephys_id  : smallint   # ephys recording number within a two-photon session
-----
voltage    : longblob   # membrane voltage
current    : longblob   # membrane current
photodiode : longblob   # photodiode signal
ekg=null   : longblob   # ekg
fs         : double     # sampling rate
ephys_ts=CURRENT_TIMESTAMP : timestamp   # automatic
%}

classdef Ephys < dj.Relvar & dj.AutoPopulate

	properties(Constant)
		table = dj.Table('tp.Ephys')
	end
	properties
		popRel = tp.Animal  
	end

	methods
		function self = Ephys(varargin)
			self.restrict(varargin)
		end

		function makeTuples(self, key)
			self.insert(key)
		end
	end
end