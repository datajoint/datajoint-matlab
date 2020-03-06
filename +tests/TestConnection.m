classdef TestConnection < tests.Prep
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
    end
end