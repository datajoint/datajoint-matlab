classdef TestFixture < matlab.unittest.TestCase
    
    properties (Constant)
        CONN_INFO = struct('host', getenv('DJ_TEST_HOST'), 'user', getenv('DJ_TEST_USER'), 'password', getenv('DJ_TEST_PASSWORD'));
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