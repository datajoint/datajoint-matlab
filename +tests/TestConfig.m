classdef TestConfig < tests.Prep
    % TestConfig tests scenarios related to initializing DJ config.
    methods (Static)
        function obj = configRemoveEnvVars(obj, type)
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
        function configSingleFileTest(test_instance, type, fname, base)
            switch type
                case 'save-local'
                    dj.config.saveLocal();
                    fname = dj.internal.Settings.LOCALFILE;
                case 'save-global'
                    dj.config.saveGlobal();
                    fname = dj.internal.Settings.GLOBALFILE;
                case 'save-custom'
                    dj.config.save(fname);
                case 'load-custom'
                    dj.config.load(fname);
            end
            % load raw
            read_data = fileread(fname);           
            obj1 = tests.TestConfig.configRemoveEnvVars(jsondecode(read_data), 'file');
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
            obj2 = tests.TestConfig.configRemoveEnvVars(dj.config(), 'config');
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
        function testGetSet(testCase)
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
        function testConfigChecks(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            testCase.verifyError(@() dj.config(9), ...
                'DataJoint:Config:InvalidType');
            d = testCase.verifyError(@() dj.config('none'), ...
                'DataJoint:Config:InvalidKey');
        end
        function testRestore(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            dj.config.restore;
            obj1 = tests.TestConfig.configRemoveEnvVars(dj.config(), 'config');
            obj2 = tests.TestConfig.configRemoveEnvVars( ...
                orderfields(dj.internal.Settings.DEFAULTS), 'config');
            testCase.verifyEqual(jsonencode(obj1), jsonencode(obj2));
        end
        function testSave(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);            
            dj.config.restore;
            
            % local
            dj.config('font', 10);
            tests.TestConfig.configSingleFileTest(testCase, 'save-local');
            % global
            dj.config('font', 12);
            tests.TestConfig.configSingleFileTest(testCase, 'save-global');
            % custom
            dj.config('font', 16);
            tests.TestConfig.configSingleFileTest(testCase, 'save-custom', './config.json');
            
            dj.config.restore;
        end
        function testLoad(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            pkg = what('tests');
            % generate default base
            default_file = [pkg.path '/test_schemas/default.json'];
            dj.config.restore;
            dj.config.save(default_file);
            defaults = tests.TestConfig.configRemoveEnvVars( ...
                jsondecode(fileread(default_file)), 'file');
            delete(default_file);
            % load test config
            tests.TestConfig.configSingleFileTest(testCase, 'load-custom', ...
                [pkg.path '/test_schemas/config.json'], defaults);
            % load new config on top of existing
            base = tests.TestConfig.configRemoveEnvVars(dj.config, 'config');
            base = jsonencode(base);
            base = regexprep(base,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            tests.TestConfig.configSingleFileTest(testCase, 'load-custom', ...
                [pkg.path '/test_schemas/config_lite.json'], jsondecode(base));
            % cleanup
            dj.config.restore;
        end
        function testEnv(testCase)
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
            pkg = what('tests');
            setenv('DJ_INIT', 'select @@version;');
            dj.config.restore;
            % check pulling from env vars
            env = {getenv('DJ_HOST'), getenv('DJ_USER'), getenv('DJ_PASS'), getenv('DJ_INIT')};
            validateEnvVarConfig('env', env);
            % check after load if env vars take precedence
            dj.config.load([pkg.path '/test_schemas/config.json']);
            validateEnvVarConfig('env', env);
            % check if overriding env vars is persisted
            validateEnvVarConfig('set', ...
                {'localhost', 'john', 'secure', 'SET SESSION sql_mode="TRADITIONAL";'});
            % cleanup
            setenv('DJ_INIT', '');
            dj.config.restore;
        end
    end
end