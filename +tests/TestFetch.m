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

            q = University.All & 'id=2';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  2);
            testCase.verifyEqual(res(1).string,  'test');
            testCase.verifyEqual(res(1).date,  '2019-12-17 13:38:00');
            testCase.verifyEqual(res(1).number,  3.213);
            testCase.verifyEqual(res(1).blob,  [1, 2; 3, 4]);
        end
        function TestFetch_testBlobScalar(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/217
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 3, ...
                'string', 'nothing', ...
                'date', '2020-03-17 20:38', ...
                'number', 9.7, ...
                'blob', 1 ...
            ));

            q = University.All & 'id=3';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).string,  'nothing');
        end
        function TestFetch_testNullable(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % related to % https://github.com/datajoint/datajoint-matlab/issues/211
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 4 ...
            ));

            q = University.All & 'id=4';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  4);
            testCase.verifyEqual(res(1).string,  '');
            testCase.verifyEqual(res(1).date,  '');
            testCase.verifyEqual(res(1).number,  NaN);
            testCase.verifyEqual(res(1).blob,  '');

            insert(University.All, struct( ...
                'id', 5, ...
                'string', '', ...
                'date', '', ...
                'number', [], ...
                'blob', [] ...
            ));

            q = University.All & 'id=5';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  5);
            testCase.verifyEqual(res(1).string,  '');
            testCase.verifyEqual(res(1).date,  '');
            testCase.verifyEqual(res(1).number,  NaN);
            testCase.verifyEqual(res(1).blob,  '');
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