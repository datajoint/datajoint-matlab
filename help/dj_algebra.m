%% Relational algebra
%
% DataJoint implements a complete and powerful relational algebra 
% 
%   %{
%   common.Animal (manual) # Basic subject info
%   animal_id       : int                   # id (internal to database)
%   ---
%   real_id                     : varchar(20)                   # real-world unique identification
%   date_of_birth=null          : date                          # animal's date of birth
%   sex="unknown"               : enum('M','F','unknown')       # 
%   animal_notes=""             : varchar(4096)                 # strain, genetic manipulations
%   animal_ts=CURRENT_TIMESTAMP : timestamp                     # automatic
%   %}
%   classdef Animal < dj.Relvar
% 	  properties(Constant)
%  	 	table = dj.Table('common.Animal')
% 	  end
%   end

common.Animal