classdef Prep < matlab.unittest.TestCase
    % Setup and teardown for tests.
    properties (Constant)
        CONN_INFO_ROOT = struct(...
            'host', getenv('DJ_HOST'), ...
            'user', getenv('DJ_USER'), ...
            'password', getenv('DJ_PASS'));
        CONN_INFO = struct(...
            'host', getenv('DJ_TEST_HOST'), ...
            'user', getenv('DJ_TEST_USER'), ...
            'password', getenv('DJ_TEST_PASSWORD'));
        S3_CONN_INFO = struct(...
            'endpoint', getenv('S3_ENDPOINT'), ...
            'access_key', getenv('S3_ACCESS_KEY'), ...
            'secret_key', getenv('S3_SECRET_KEY'), ...
            'bucket', getenv('S3_BUCKET'));
        PREFIX = 'djtest';
    end
    properties
        test_root;
    end
    methods
        function obj = Prep()
            % Initialize test_root
            test_pkg_details = what('tests');
            [test_root, ~, ~] = fileparts(test_pkg_details.path);
            obj.test_root = [test_root '/+tests'];
        end
     end
    methods (TestClassSetup)
        function init(testCase)
            disp('---------------INIT---------------');
            clear functions;
            addpath([testCase.test_root '/test_schemas']);

            curr_conn = dj.conn(testCase.CONN_INFO_ROOT.host, ...
                testCase.CONN_INFO_ROOT.user, testCase.CONN_INFO_ROOT.password,'',true);
            % create test users
            ver = curr_conn.query('select @@version as version').version;
            if tests.lib.compareVersions(ver,'5.8')
                cmd = {...
                'CREATE USER IF NOT EXISTS ''datajoint''@''%%'' '
                'IDENTIFIED BY ''datajoint'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'GRANT ALL PRIVILEGES ON `djtest%%`.* TO ''datajoint''@''%%'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'CREATE USER IF NOT EXISTS ''djview''@''%%'' '
                'IDENTIFIED BY ''djview'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'GRANT SELECT ON `djtest%%`.* TO ''djview''@''%%'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'CREATE USER IF NOT EXISTS ''djssl''@''%%'' '
                'IDENTIFIED BY ''djssl'' '
                'REQUIRE SSL;'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'GRANT SELECT ON `djtest%%`.* TO ''djssl''@''%%'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));
            else
                cmd = {...
                'GRANT ALL PRIVILEGES ON `djtest%%`.* TO ''datajoint''@''%%'' '
                'IDENTIFIED BY ''datajoint'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'GRANT SELECT ON `djtest%%`.* TO ''djview''@''%%'' '
                'IDENTIFIED BY ''djview'';'
                };
                curr_conn.query(sprintf('%s',cmd{:}));

                cmd = {...
                'GRANT SELECT ON `djtest%%`.* TO ''djssl''@''%%'' '
                'IDENTIFIED BY ''djssl'' '
                'REQUIRE SSL;'
                };
                curr_conn.query(sprintf('%s',cmd{:}));
            end
        end
    end
    methods (TestClassTeardown)
        function dispose(testCase)
            disp('---------------DISP---------------');
            warning('off','MATLAB:RMDIR:RemovedFromPath');

            curr_conn = dj.conn(testCase.CONN_INFO_ROOT.host, ...
                testCase.CONN_INFO_ROOT.user, testCase.CONN_INFO_ROOT.password, '',true);

            % remove databases
            curr_conn.query('SET FOREIGN_KEY_CHECKS=0;');
            res = curr_conn.query(['SHOW DATABASES LIKE "' testCase.PREFIX '_%";']);
            for i = 1:length(res.(['Database (' testCase.PREFIX '_%)']))
                curr_conn.query(['DROP DATABASE ' ...
                    res.(['Database (' testCase.PREFIX '_%)']){i} ';']);
            end
            curr_conn.query('SET FOREIGN_KEY_CHECKS=1;');

            % remove users
            cmd = {...
            'DROP USER ''datajoint''@''%%'';'
            'DROP USER ''djview''@''%%'';'
            'DROP USER ''djssl''@''%%'';'
            };
            res = curr_conn.query(sprintf('%s',cmd{:}));
            curr_conn.delete;

            % Remove getSchemas to ensure they are created by tests.
            files = dir([testCase.test_root '/test_schemas']);
            dirFlags = [files.isdir] & ~strcmp({files.name},'.') & ~strcmp({files.name},'..');
            subFolders = files(dirFlags);
            for k = 1 : length(subFolders)
                delete([testCase.test_root '/test_schemas/' subFolders(k).name ...
                    '/getSchema.m']);
                % delete(['test_schemas/+University/getSchema.m'])
            end
            rmpath([testCase.test_root '/test_schemas']);
            warning('on','MATLAB:RMDIR:RemovedFromPath');
        end
    end
end