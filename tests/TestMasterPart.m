classdef TestMasterPart < Prep
    methods(Test)
        function TestMasterPart_testCascadingDelete(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'Acquisition';
            
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_acquisition']);
            
            %% setup db
            Acquisition.Acquisition().insert(struct('id',{1,2,3,4}));
            Acquisition.AcquisitionRound().insert(struct('id',{1,1,2,3,4},'round',{1,2,1,2,3}));
            Acquisition.Segment().populate();
            Acquisition.SAR().insert(struct('id',1,'round',1));

            testCase.verifyEqual(count(Acquisition.Acquisition), 4);
            testCase.verifyEqual(count(Acquisition.AcquisitionRound), 5);
            testCase.verifyEqual(count(Acquisition.Segment), 3);
            testCase.verifyEqual(count(Acquisition.SegmentRound), 4);
            testCase.verifyEqual(count(Acquisition.SegmentSubsegment), 6);
            testCase.verifyEqual(count(Acquisition.SAR), 1);

            %% deletion of part table dependency should cascade to master
            del(Acquisition.AcquisitionRound & 'round=1');

            testCase.verifyEqual(count(Acquisition.Acquisition), 4);
            testCase.verifyEqual(count(Acquisition.AcquisitionRound), 3);
            testCase.verifyEqual(count(Acquisition.Segment), 1); %master which doesn't inherit from starting relation
            testCase.verifyEqual(count(Acquisition.SegmentRound), 1);
            testCase.verifyEqual(count(Acquisition.SegmentSubsegment), 2); %non-inheriting part of master
            testCase.verifyEqual(count(Acquisition.SAR), 0); %dependency of both starting relation and master


            %% master should update when there are new valid parts
            Acquisition.Segment().populate();
            Acquisition.AcquisitionRound().insert(struct('id',{1,2},'round',{1,1}));
            Acquisition.Segment().populate();
            testCase.verifyEqual(count(Acquisition.Segment), 3);
            testCase.verifyEqual(count(Acquisition.SegmentRound), 4); %requires a proper 'target' property on master


        end
    end
end
