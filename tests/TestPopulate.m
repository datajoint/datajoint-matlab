classdef TestPopulate < Prep
    methods(Test)
        function TestPopulate_testPopulate(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'Lab';
            
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_lab']);
            
            schema = Lab.getSchema; % use schema's connection to verify id

            insert(Lab.Subject, {
               100, '2010-04-02';
            });

            insert(Lab.Rig, struct( ...
                'rig_manufacturer', 'FooLab', ...
                'rig_model', '1.0', ...
                'rig_note', 'FooLab Frobnicator v1.0' ...
            ));

            % parallel populate of 1 record
            % .. (SessionAnalysis logs session ID as session_analysis data)
            % NOTE: need to call parpopulate 1st to ensure Jobs table
            % exists

            insert(Lab.Session, struct( ...
                'session_id', 0, ...
                'subject_id', 100, ...
                'rig_manufacturer', 'FooLab', ...
                'rig_model', '1.0' ...
            ));

            parpopulate(Lab.SessionAnalysis);
            a_result = fetch(Lab.SessionAnalysis & 'session_id = 0', '*');
            testCase.verifyEqual(a_result.session_analysis.connection_id, schema.serverId);

            % regular populate of 1 record
            % .. (SessionAnalysis logs jobs record as session_analysis data)

            insert(Lab.Session, struct( ...
                'session_id', 1, ...
                'subject_id', 100, ...
                'rig_manufacturer', 'FooLab', ...
                'rig_model', '1.0' ...
            ));

            populate(Lab.SessionAnalysis);
            a_result = fetch(Lab.SessionAnalysis & 'session_id = 1', '*');
            testCase.verifyEqual(a_result.session_analysis, 1);

        end
    end
end
