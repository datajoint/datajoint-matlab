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
    end
end