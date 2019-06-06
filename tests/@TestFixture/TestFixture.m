classdef TestFixture < matlab.unittest.TestCase
    
    properties (Constant)
        CONN_INFO = struct('host', getenv('DJ_HOST'), 'user', getenv('DJ_USER'), 'password', getenv('DJ_PASS'));
    end

    methods (TestClassSetup)
        function init(testCase)
            addpath('..');
            testCase.addTeardown(@testCase.dispose);
        end
    end
    
    methods (Test)
        testConnection(testCase)
    end
    
    methods (Static)
        function dispose()
            clear functions;
        end
    end
end