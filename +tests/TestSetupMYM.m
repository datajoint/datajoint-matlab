
classdef TestSetupMYM < tests.Prep
% TestSetupMyM tests setupMYM

    methods (Test)
        function TestSetupMYM_testDefaultInstall(testCase)

            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if isdir(tmym)
                fprintf('testDefaultInstall: mymdir %s exists. removing\n', ...
                        tmym);
                rmdir(tmym, 's');
            end
            
            ms = setupMYM();
            testCase.verifyTrue(strcmp(ms, 'master'));
            testCase.verifyTrue(isdir(tmym));

        end
        function TestSetupMYM_testVersionInstallFresh(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if isdir(tmym)
                fprintf('testVersionInstallFresh: removing mymdir %s\n', ...
                        tmym);
                rmdir(tmym, 's');
            end

            % TODO: how manage version string?
            ms = setupMYM('2.7.2');
            testCase.verifyTrue(strcmp(ms, '2.7.2'));
            testCase.verifyTrue(isdir(tmym));

        end
        function TestSetupMYM_testVersionInstallStale(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if ~isdir(tmym)  % XXX: valid? how handle otherwise?
                fprintf('testVersionInstallStale: spoofing mymdir %s\n', ...
                        tmym);
                mkdir(tmym);
                testCase.verifyTrue(isdir(tmym));
            end

            % TODO: how manage version string?
            ms = setupMYM('2.7.2'); % TODO: how properly verify?
                                    % also: .. persistent & test state ...

        end
        function TestSetupMYM_testVersionInstallStaleForce(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if ~isdir(tmym)  % XXX: valid? how handle otherwise?
                fprintf('testVersionInstallStaleForce: spoofing mymdir %s\n', ...
                        tmym);
                mkdir(tmym);
                testCase.verifyTrue(isdir(tmym));
            end

            % TODO: how manage version string?
            ms = setupMYM('2.7.2', true);
            testCase.verifyTrue(strcmp(ms, '2.7.2'));
            testCase.verifyTrue(isdir(tmym));

        end
        function TestSetupMYM_testMasterInstallFresh(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if isdir(tmym)
                fprintf('testMasterInstallFresh: removing mymdir %s\n', ...
                        tmym);
                rmdir(tmym, 's');
            end

            ms = setupMYM('master');
            testCase.verifyTrue(strcmp(ms, 'master'));
            testCase.verifyTrue(isdir(tmym));

        end
        function TestSetupMYM_testMasterInstallStale(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if ~isdir(tmym)  % XXX: valid? how handle otherwise?
                fprintf('testMasterInstallStale: spoofing mymdir %s\n', ...
                        tmym);
                mkdir(tmym);
                testCase.verifyTrue(isdir(tmym));
            end

            ms = setupMYM('master'); % TODO: how verify fail?
                                     % also: .. persistent & test state ...
        end
        function TestSetupMYM_testMasterInstallStaleForce(testCase)
            [dir, nam, ext] = fileparts(mfilename('fullpath'));
            tmym = strcat(dir, '/../', 'mym');

            if ~isdir(tmym)  % XXX: valid? how handle otherwise?
                fprintf('testMasterInstallStaleForce: spoofing mymdir %s\n', ...
                        tmym);
                mkdir(tmym);
                testCase.verifyTrue(isdir(tmym));
            end

            ms = setupMYM('master');
            testCase.verifyTrue(strcmp(ms, 'master'));
            testCase.verifyTrue(isdir(tmym));

        end
    end
end
