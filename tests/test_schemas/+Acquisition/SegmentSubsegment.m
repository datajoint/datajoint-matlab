%{
-> Acquisition.Segment
subsegment: int
%}
classdef SegmentSubsegment < dj.Part
    properties(SetAccess=protected)
        master = Acquisition.Segment
    end
end
