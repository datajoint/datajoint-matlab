%{
-> Acquisition.Segment
---
duplicate_column: int
%}
classdef SegmentMiscellaneous < dj.Part
    properties(SetAccess=protected)
        master = Acquisition.Segment
    end
end
