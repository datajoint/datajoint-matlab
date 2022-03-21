classdef TestConfig < Prep
    % TestConfig tests scenarios related to initializing DJ config.
    methods (Static)
        function obj = TestConfig_configRemoveEnvVars(obj, type)
            switch type
                case 'file'
                    if isfield(obj, 'database_host')
                        obj = rmfield(obj, 'database_host');
                    end
                    if isfield(obj, 'database_user')
                        obj = rmfield(obj, 'database_user');
                    end
                    if isfield(obj, 'database_password')
                        obj = rmfield(obj, 'database_password');
                    end
                    if isfield(obj, 'connection_init_function')
                        obj = rmfield(obj, 'connection_init_function');
                    end
                case 'config'
                    if isfield(obj, 'databaseHost')
                        obj = rmfield(obj, 'databaseHost');
                    end
                    if isfield(obj, 'databaseUser')
                        obj = rmfield(obj, 'databaseUser');
                    end
                    if isfield(obj, 'databasePassword')
                        obj = rmfield(obj, 'databasePassword');
                    end
                    if isfield(obj, 'connectionInit_function')
                        obj = rmfield(obj, 'connectionInit_function');
                    end
            end
        end
        function TestConfig_configSingleFileTest(test_instance, type, fname, base)
            switch type
                case 'save-local'
                    dj.config.saveLocal();
                    fname = dj.internal.Settings.LOCALFILE;
                case 'save-global'
                    dj.config.saveGlobal();
                    fname = dj.internal.Settings.GLOBALFILE;
                    if ispc
                        fname = strrep(fname, '~', strrep(getenv('USERPROFILE'), '\', '/'));
                    end
                case 'save-custom'
                    dj.config.save(fname);
                case 'load-custom'
                    dj.config.load(fname);
            end
            % load raw
            read_data = fileread(fname);           
            obj1 = TestConfig.TestConfig_configRemoveEnvVars(jsondecode(read_data), 'file');
            % optional merge from base
            if strcmpi(type, 'load-custom')
                tmp = rmfield(base, intersect(fieldnames(base), fieldnames(obj1)));
                names = [fieldnames(tmp); fieldnames(obj1)];
                obj1 = orderfields(cell2struct([struct2cell(tmp); ...
                    struct2cell(obj1)], names, 1));
            end
            % stringify
            file = jsonencode(obj1);
            % load config
            obj2 = TestConfig.TestConfig_configRemoveEnvVars(dj.config(), 'config');
            curr = jsonencode(obj2);
            curr = regexprep(curr,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            % checks
            verifyEqual(test_instance, curr, file);
            assert(~contains(read_data, '[]'));
            % optional remove file
            if ~strcmpi(type, 'load-custom')
                delete(fname);
            end
        end
    end
    methods (Test)
        function TestConfig_testGetSet(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            function verifyConfig(new, previous_value, subref, subref_value, subref_prev)
                keys = fieldnames(new);
                try
                    c_prev = dj.config(keys{1}, new.(keys{1}));
                catch ME
                    switch ME.identifier
                        case 'DataJoint:Config:InvalidKey'
                            dj.config(keys{1}, new.(keys{1}));
                        otherwise
                            rethrow(ME);
                    end
                end
                c_curr = dj.config(keys{1});
                if nargin > 1
                    verifyEqual(testCase, c_prev, previous_value);
                elseif exist('c_prev','var')
                    verifyNotEqual(testCase, c_curr, c_prev);
                end
                verifyEqual(testCase, c_curr, new.(keys{1}));
                if exist('subref','var')
                    % eval less efficient but keeps test simple for 1 test
                    eval(['c_prev = dj.config(''' subref ''', ''' subref_value ''');']);
                    eval(['c_curr = dj.config(''' subref ''');']);
                    verifyEqual(testCase, c_prev, subref_prev);
                    verifyEqual(testCase, c_curr, subref_value);
                    eval(['new.' subref ' = subref_value;']);
                    verifyEqual(testCase, dj.config(keys{1}), new.(keys{1}));
                end
            end
            dj.config.restore;
            % check update a default config
            verifyConfig(struct('displayLimit', 15));
            % check create new config
            prev = 'Neuro';
            verifyConfig(struct('project', prev));
            % check update newly created config
            verifyConfig(struct('project', 'Lab'), prev);
            % check create new struct array config
            prev = [ ...
                struct(...
                    'protocol', 'file', ...
                    'location', '/tmp', ...
                    'subfolding', [1,1] ...
            ), struct(...
                    'protocol', 's3', ...
                    'location', '/home', ...
                    'subfolding', [2,2] ...
            )];
            verifyConfig(struct('stores', prev));
            % check update to cell array config, and check update nested config
            verifyConfig(struct('stores', {{ ...
                struct(...
                    'protocol', 'file', ...
                    'location', '/tmp', ...
                    'subfolding', [1,1] ...
            ), struct(...
                    'protocol', 's3', ...
                    'location', '/home', ...
                    'subfolding', [2,2] ...
            )}}), prev, 'stores{2}.protocol', 'http', 's3');
        end
        function TestConfig_testConfigChecks(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            testCase.verifyError(@() dj.config(9), ...
                'DataJoint:Config:InvalidType');
            try
                d = dj.config('none');
            catch ME
                if ~strcmp(ME.identifier,'DataJoint:Config:InvalidKey')
                    rethrow(ME);
                end
            end
        end
        function TestConfig_testRestore(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.config.restore;
            obj1 = TestConfig.TestConfig_configRemoveEnvVars(dj.config(), 'config');
            obj2 = TestConfig.TestConfig_configRemoveEnvVars( ...
                orderfields(dj.internal.Settings.DEFAULTS), 'config');
            testCase.verifyEqual(jsonencode(obj1), jsonencode(obj2));
        end
        function TestConfig_testSave(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);            
            dj.config.restore;
            
            % local
            dj.config('font', 10);
            TestConfig.TestConfig_configSingleFileTest(testCase, 'save-local');
            % global
            dj.config('font', 12);
            TestConfig.TestConfig_configSingleFileTest(testCase, 'save-global');
            % custom
            dj.config('font', 16);
            TestConfig.TestConfig_configSingleFileTest(...
                testCase, 'save-custom', './config.json');
            
            dj.config.restore;
        end
        function TestConfig_testLoad(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            pkg_path = testCase.test_root;
            % generate default base
            default_file = [pkg_path '/test_schemas/default.json'];
            dj.config.restore;
            dj.config.save(default_file);
            defaults = TestConfig.TestConfig_configRemoveEnvVars( ...
                jsondecode(fileread(default_file)), 'file');
            delete(default_file);
            % load test config
            TestConfig.TestConfig_configSingleFileTest(testCase, 'load-custom', ...
                [pkg_path '/test_schemas/config.json'], defaults);
            % load new config on top of existing
            base = TestConfig.TestConfig_configRemoveEnvVars(dj.config, 'config');
            base = jsonencode(base);
            base = regexprep(base,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            TestConfig.TestConfig_configSingleFileTest(testCase, 'load-custom', ...
                [pkg_path '/test_schemas/config_lite.json'], jsondecode(base));
            % test load on launch MATLAB
            clear functions;
            dj.config.load(sprintf('%s/test_schemas/config_lite.json', pkg_path));
            try
                port = dj.config('databasePort');
                testCase.verifyEqual(port, 3306);
            catch ME
                switch ME.identifier
                    case 'DataJoint:Config:InvalidKey'
                        % cleanup
                        dj.config.restore;
                        rethrow(ME);
                    otherwise
                        % cleanup
                        dj.config.restore;
                end
            end
        end
        function TestConfig_testEnv(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            function validateEnvVarConfig(type, values)
                switch type
                    case 'set'
                        dj.config('databaseHost', values{1});
                        dj.config('databaseUser', values{2});
                        dj.config('databasePassword', values{3});
                        dj.config('connectionInit_function', values{4});
                end
                testCase.verifyEqual(dj.config('databaseHost'), values{1});
                testCase.verifyEqual(dj.config('databaseUser'), values{2});
                testCase.verifyEqual(dj.config('databasePassword'), values{3});
                testCase.verifyEqual(dj.config('connectionInit_function'), values{4});
            end
            pkg_path = testCase.test_root;
            setenv('DJ_INIT', 'select @@version;');
            dj.config.restore;
            % check pulling from env vars
            env = {getenv('DJ_HOST'), getenv('DJ_USER'), getenv('DJ_PASS'), getenv('DJ_INIT')};
            validateEnvVarConfig('env', env);
            % check after load if env vars take precedence
            dj.config.load([pkg_path '/test_schemas/config.json']);
            validateEnvVarConfig('env', env);
            % check if overriding env vars is persisted
            validateEnvVarConfig('set', ...
                {'localhost', 'john', 'secure', 'SET SESSION sql_mode="TRADITIONAL";'});
            % cleanup
            setenv('DJ_INIT', '');
            dj.config.restore;
        end
        function TestConfig_testUse32BitDims(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.config('use_32bit_dims', true);
            testCase.verifyEqual(getenv('MYM_USE_32BIT_DIMS'), 'true');
            dj.config('use_32bit_dims', false);
            testCase.verifyEqual(getenv('MYM_USE_32BIT_DIMS'), 'false');
            
            dj.config.restore;
        end
    end
end