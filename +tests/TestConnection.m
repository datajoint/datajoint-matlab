classdef TestConnection < matlab.unittest.TestCase
    % TestConnection tests typical connection scenarios.
    methods (Test)
        function testConnection(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            testCase.verifyTrue(dj.conn(...
                testCase.CONN_INFO.host,...
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true).isConnected);
        end
        function testConnectionExists(testCase)
            % testConnectionExists tests that will not fail if connection open
            % to the same host.
            % Fix https://github.com/datajoint/datajoint-matlab/issues/160
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true)
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true)
        end
        function testConnectionDiffHost(testCase)
            % testConnectionDiffHost tests that will fail if connection open
            % to a different host.
            % Fix https://github.com/datajoint/datajoint-matlab/issues/160
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.conn(testCase.CONN_INFO.host, '', '', '', '', true)
            
            testCase.verifyError(@() dj.conn(...
                'anything', '', '', '', '', true), ...
                'DataJoint:Connection:AlreadyInstantiated');
        end
    end
end