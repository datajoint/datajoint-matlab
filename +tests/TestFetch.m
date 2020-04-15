classdef TestFetch < tests.Prep
    % TestFetch tests typical insert/fetch scenarios.
    methods (Test)
        function TestFetch_testVariousDatatypes(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 2, ...
                'string', 'test', ...
                'date', '2019-12-17 13:38', ...
                'number', 3.213, ...
                'blob', [1, 2; 3, 4] ...
            ));

            q = University.All;
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  2);
            testCase.verifyEqual(res(1).string,  'test');
            testCase.verifyEqual(res(1).date,  '2019-12-17 13:38:00');
            testCase.verifyEqual(res(1).number,  3.213);
            testCase.verifyEqual(res(1).blob,  [1, 2; 3, 4]);
        end
        function TestFetch_testShan(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'External';

            % dj.config('stores.mesoimaging', struct('location', '~/meso_imaging', 'protocol', 'file'))

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_ext']);

            new_value = struct();
            new_value.segmentation_method = 'cnmf';
            new_value.seg_parameter_set_id = 1;
            new_value.subject_fullname = 'lpinto_SP6';
            new_value.session_date = '2019-10-16';
            new_value.session_number = 0;
            new_value.fov = 1;
            new_value.num_chunks = 1;
            new_value.cross_chunks_x_shifts = 0;
            new_value.cross_chunks_y_shifts = 0;
            % new_value.cross_chunks_x_shifts = [1,2];
            % new_value.cross_chunks_y_shifts = [1,2];
            new_value.test = 'hello';
            % new_value.cross_chunks_reference_image = single([2,3]);

            insert(External.Debug, new_value);

            q = External.Debug;
            res = q.fetch('*');

            testCase.verifyEqual(res(1).test,  'hello');

            % dj.config.restore;
        end
        function TestFetch_testDescribe(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            q = University.All;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            assembled_sql = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
        end
    end
end