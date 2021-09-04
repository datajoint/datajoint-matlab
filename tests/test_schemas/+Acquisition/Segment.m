%{
->Acquisition.Acquisition
%}
classdef Segment < dj.Computed
    properties(Constant)
        keySource = Acquisition.AcquisitionRound & 'round<3';
        target = Acquisition.SegmentRound;
    end
    
    
    
    methods(Access=protected)
        function makeTuples(self,key)
            
            key = [self.primaryKey; cellfun(@(x) key.(x), self.primaryKey, 'uni', 0)];
            key = struct(key{:});
            if count(self & key)
               %there's already an entry for this key 
                del(self & key, 1); %clear the dependencies
                %note: want to maintain the transaction!
            end

            %proceed with the normal population
            self.insert(key)
            key2 = key;
            for n=1:2
                key.subsegment = n;
                key2.round = n;
                try %can only actually insert if there's a matching acquisition_round
                    Acquisition.SegmentRound().insert(key2);
                end
                Acquisition.SegmentSubsegment().insert(key);
            end
        end
    end
end