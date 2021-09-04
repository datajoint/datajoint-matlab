%{
-> Acquisition.Segment
-> Acquisition.AcquisitionRound
%}
classdef SegmentRound < dj.Part
    properties(SetAccess=protected)
        master = Acquisition.Segment
    end
end
