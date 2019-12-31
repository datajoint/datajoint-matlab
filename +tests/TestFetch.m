classdef TestFetch < tests.Prep
    % TestFetch tests typical insert/fetch scenarios.
    methods (Test)
        function testVariousDatatypes(testCase)
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
        function testReverseEngineering(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            q = University.All;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            raw_sql = dj.internal.Declare.declare(q, raw_def);
            assembled_sql = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
        end
    end
end