%{
tp.Animal (manual) # Basic subject info
animal_id        : int      # internal id
---
species='mouse'     : enum('test','mouse','monkey')   # add details in 'notes'
real_id             : varchar(20)   # real-world unique identification 
date_of_birth=null  : date          # animal's date of birth
sex="unknown"       : enum('M','F','unknown')  # 
animal_notes=""     : varchar(4096) # strain, genetic manipulations
animal_ts=CURRENT_TIMESTAMP : timestamp     # automatic
%}



classdef Animal < dj.Relvar

	properties(Constant)
		table = dj.Table('tp.Animal')
	end

	methods
		function self = Animal(varargin)
			self.restrict(varargin)
		end
	end
end