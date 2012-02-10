%{
tp.Session (manual)  # two-photon session (same objective, same base path)
session_id : int     # session id
-----
-> tp.Animal
-> tp.Calibration
data_path          : varchar(255)      # root file path
basename           : varchar(255)      # scanimage base filename name
anesthesia="other"           : enum('isoflurane','fentanyl','urethane','other')   # per protocol
session_notes    : varchar(4095)  # free-text notes
session_ts=CURRENT_TIMESTAMP : timestamp # automatic
%}

classdef Session < dj.Relvar

	properties(Constant)
		table = dj.Table('tp.Session')
	end

	methods
		function self = Session(varargin)
			self.restrict(varargin)
		end
	end
end