classdef TestExternalS3 < tests.Prep
    % TestExternalS3 tests scenarios related to external S3 store.
    methods (Test)
        function TestExternalS3_testRemote(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'new_remote', 'blobCache');
        end
        function TestExternalS3_testRemoteDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'new_remote_default', ...
                'blobCache');
        end
        function TestExternalS3_testBackward(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'remote', 'cache');
        end
        function TestExternalS3_testBackwardDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'remote_default', 'cache');
        end
    end
end