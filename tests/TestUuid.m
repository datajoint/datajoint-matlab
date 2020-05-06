classdef TestUuid < Prep
    % TestUuid tests uuid scenarios.
    methods (Test)
        function TestUuid_testInsertFetch(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            test_val1 = '1d751e2e-1e74-faf8-4ab4-85fde8ef72be';
            test_val2 = '03aaa83d-289d-4f7e-96a7-bf91c2d8f5a4';
            insert(University.Message, struct( ...
                'msg_id', test_val1, ...
                'body', 'Great campus!', ...
                'dep_id', test_val2 ...
            ));

            test_val1 = '12321346-1312-4123-1234-312739283795';
            insert(University.Message, struct( ...
                'msg_id', strrep(test_val1, '-', ''), ...
                'body', 'Where can I find the gym?' ...
            ));

            q = University.Message;
            res = q.fetch('*');
            testCase.verifyEqual(res(1).msg_id,  test_val1);
            testCase.verifyEqual(res(1).dep_id,  uint8.empty(1, 0));
        end
        function TestUuid_testQuery(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            test_val1 = '1d751e2e-1e74-faf8-4ab4-85fde8ef72be';
            test_val2 = '12321346-1312-4123-1234-312739283795';

            q = University.Message & [struct('msg_id',test_val1),struct('msg_id',test_val2)];
            res = q.fetch('msg_id');
            value_check = res(2).msg_id;

            testCase.verifyEqual(value_check,  test_val1);
        end
        function TestUuid_testReverseEngineering(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            q = University.Message;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
        end
    end
end