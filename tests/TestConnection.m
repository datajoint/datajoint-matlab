classdef TestConnection < Prep
    % TestConnection tests typical connection scenarios.
    methods (Test)
        function TestConnection_testConnection(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            testCase.verifyTrue(dj.conn(...
                testCase.CONN_INFO.host,...
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true).isConnected);
        end
        function TestConnection_testConnectionExists(testCase)
            % testConnectionExists tests that will not fail if connection open
            % to the same host.
            % Fix https://github.com/datajoint/datajoint-matlab/issues/160
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true);
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true);
        end
        function TestConnection_testConnectionDiffHost(testCase)
            % testConnectionDiffHost tests that will fail if connection open
            % to a different host.
            % Fix https://github.com/datajoint/datajoint-matlab/issues/160
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true);
            
            testCase.verifyError(@() dj.conn(...
                'anything', '', '', '', '', true), ...
                'DataJoint:Connection:AlreadyInstantiated');
        end
        function TestConnection_testPort(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            testCase.verifyError(@() dj.conn(...
                [testCase.CONN_INFO.host ':3307'], ...
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true), ...
                'MySQL:Error');
        end
        function TestConnection_testTransactionRollback(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);
            schema = University.getSchema;
            tmp = {
                20   'Henry'   'Jupyter' '2020-11-25 12:34:56'
                21   'Lacy'   'Mars' '2017-11-25 12:34:56'
            };

            insert(University.Student, tmp(1, :));

            schema.conn.startTransaction
            try
                insert(University.Student, tmp(2, :));
                assert(false, 'Customer:Error', 'Message')
            catch ME
                schema.conn.cancelTransaction
                if ~strcmp(ME.identifier,'Customer:Error')
                    rethrow(ME);
                end
            end

            q = University.Student & 'student_id in (20,21)';
            testCase.verifyEqual(q.count, 1);
            testCase.verifyEqual(q.fetch1('student_id'), 20);
        end
    end
end