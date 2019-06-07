classdef TestFixture < matlab.unittest.TestCase
    
    properties (Constant)
        CONN_INFO = struct(...
            'host', getenv('DJ_TEST_HOST'), ...
            'user', getenv('DJ_TEST_USER'), ...
            'password', getenv('DJ_TEST_PASSWORD'));
    end

    methods (TestClassSetup)
        function init(testCase)
            disp('---------------INIT---------------');
            addpath('..');
            testCase.addTeardown(@testCase.dispose);
        end
    end
    
    methods (Test)
        testConnection(testCase)
    end
    
    methods (Static)
        function dispose()
            disp('---------------DISP---------------');
            warning('off','MATLAB:RMDIR:RemovedFromPath');
            
            clear functions;
            rmdir('../mym', 's');

            warning('on','MATLAB:RMDIR:RemovedFromPath');
        end
    end
end