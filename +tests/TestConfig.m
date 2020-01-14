classdef TestConfig < tests.Prep
    % TestConfig tests scenarios related to initializing DJ config.
    methods (Test)
%         function testDisplay(testCase)
%             st = dbstack;
%             disp(['---------------' st(1).name '---------------']);
%             % just print dj.config (no input, no output) (remove env vars)
%             all_config_display = evalc("dj.config");
%             all_config_display = splitlines(all_config_display);
%             all_config_display(1)=[];
%             all_config_display(1)=[];
%             all_config_display(1)=[];
%             all_config_display(end)=[];
%             all_config_display(end)=[];
%             all_config_display(1:3) = [];
% 
%             actual_config_display = evalc("dj.config.DEFAULTS");
%             actual_config_display = splitlines(actual_config_display);
%             actual_config_display(1)=[];
%             actual_config_display(1)=[];
%             actual_config_display(1)=[];
%             actual_config_display(1)=[];
%             actual_config_display(1)=[];
%             actual_config_display(end)=[];
%             actual_config_display(end)=[];
%             actual_config_display(1:3) = [];
%             assert(tests.lib.celleq(all_config_display, actual_config_display));
%             
%             % if an out var, resturn the current state (no field)
%             all_config_display = evalc("c = dj.config");
%             all_config_display = splitlines(all_config_display);
%             all_config_display(1)=[];
%             all_config_display(1)=[];
%             all_config_display(1)=[];
%             all_config_display(end)=[];
%             all_config_display(end)=[];
% 
%             all_config_result = evalc("d = dj.config().result");
%             all_config_result = splitlines(all_config_result);
%             all_config_result(1)=[];
%             all_config_result(1)=[];
%             all_config_result(1)=[];
%             all_config_result(1)=[];
%             all_config_result(1)=[];
%             all_config_result(end)=[];
%             all_config_result(end)=[];
%             assert(tests.lib.celleq(all_config_display, all_config_result));
% 
%             % if 1 input, not restore, return state vaue for field
%             part_config_display = evalc("c = dj.config('maxPreviewRows')");
%             part_config_display = splitlines(part_config_display);
%             part_config_display(1)=[];
%             part_config_display(1)=[];
%             part_config_display(1)=[];
%             part_config_display(end)=[];
%             part_config_display(end)=[];
% 
%             part_config_result = evalc("d = dj.config('maxPreviewRows').result");
%             part_config_result = splitlines(part_config_result);
%             part_config_result(1)=[];
%             part_config_result(1)=[];
%             part_config_result(1)=[];
%             part_config_result(end)=[];
%             part_config_result(end)=[];
%             assert(tests.lib.celleq(part_config_display, part_config_result));
% 
%             % dj.config
%             % c = dj.config
%             % d = dj.config().result
%             % c = dj.config('maxPreviewRows')
%             % d = dj.config('maxPreviewRows').result
%         end
        function testGetSet(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % if 2 inputs, not restore, return previous value and set new value for field
            c = dj.config('displayLimit', 15);
            assert(c ~= 15);
            d = dj.config('displayLimit');
            assert(d == 15);
            dj.config('project', 'Neuro');
            d = dj.config('project', 'Lab');
            assert(strcmp(d, 'Neuro'));
            e = dj.config('project');
            assert(strcmp(e, 'Lab'));
            dj.config('stores', [struct(... % check that array of struct is also fine
                'protocol', 'file', ...
                'location', '/tmp', ...
                'subfolding', [1,1] ...
            ), struct(...
                'protocol', 's3', ...
                'location', '/home', ...
                'subfolding', [2,2] ...
            )]);
            d = dj.config('stores(2).protocol');
            assert(strcmp(d, 's3'));
            dj.config('stores', {struct(... % check that array of struct is also fine
                'protocol', 'file', ...
                'location', '/tmp', ...
                'subfolding', [1,1] ...
            ), struct(...
                'protocol', 's3', ...
                'location', '/home', ...
                'subfolding', [2,2] ...
            )});
            d = dj.config('stores{2}.protocol');
            assert(strcmp(d, 's3'));
            dj.config('stores{1}.protocol', 'db');
            d = dj.config('stores{1}.protocol');
            assert(strcmp(d, 'db')); % check that changed and pop off and check that has not changed the rest
        end
        function testConfigChecks(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % if more than 1 inputs, check asserts (2: field string, field exists)

            testCase.verifyError(@() dj.config(9), ...
                'DataJoint:Config:InvalidType');

            d = testCase.verifyError(@() dj.config('none'), ...
                'DataJoint:Config:InvalidKey');
        end
        function testRestore(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % change and restore
            dj.config.restore;
            obj1 = dj.config();
            obj1 = rmfield(obj1, 'databaseHost');
            obj1 = rmfield(obj1, 'databaseUser');
            obj1 = rmfield(obj1, 'databasePassword');
            obj1 = rmfield(obj1, 'connectionInit_function');
            obj2 = orderfields(dj.internal.Settings.DEFAULTS);
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            testCase.verifyEqual(jsonencode(obj1), jsonencode(obj2));
        end
        function testSave(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);

            % check local save
            % restore config
            dj.config.restore;
            % set config
            dj.config('font', 10);
            % save config
            dj.config.saveLocal();
            % load into an obj and encode
            read_data = fileread(dj.internal.Settings.LOCALFILE);
            obj1 = jsondecode(read_data);
            obj1 = rmfield(obj1, 'database_host');
            obj1 = rmfield(obj1, 'database_user');
            obj1 = rmfield(obj1, 'database_password');
            obj1 = rmfield(obj1, 'connection_init_function');
            file = jsonencode(obj1);
            % compare against current config encoded
            obj2 = dj.config();
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            curr = jsonencode(obj2);
            curr = regexprep(curr,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            testCase.verifyEqual(file, curr);
            assert(~contains(read_data, '[]'));

            delete(dj.internal.Settings.LOCALFILE);

            % check global save
            % restore config
            dj.config.restore;
            % set config
            dj.config('font', 12);
            % save config
            dj.config.saveGlobal();
            % load into an obj and encode
            read_data = fileread(dj.internal.Settings.GLOBALFILE);
            obj1 = jsondecode(read_data);
            obj1 = rmfield(obj1, 'database_host');
            obj1 = rmfield(obj1, 'database_user');
            obj1 = rmfield(obj1, 'database_password');
            obj1 = rmfield(obj1, 'connection_init_function');
            file = jsonencode(obj1);
            % compare against current config encoded
            obj2 = dj.config();
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            curr = jsonencode(obj2);
            curr = regexprep(curr,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            testCase.verifyEqual(file, curr);
            assert(~contains(read_data, '[]'));

            delete(dj.internal.Settings.GLOBALFILE);

            % check custom save
            fname = './config.json';
            % restore config
            dj.config.restore;
            % set config
            dj.config('font', 16);
            % save config
            dj.config.save(fname);
            % load into an obj and encode
            read_data = fileread(fname);
            obj1 = jsondecode(read_data);
            obj1 = rmfield(obj1, 'database_host');
            obj1 = rmfield(obj1, 'database_user');
            obj1 = rmfield(obj1, 'database_password');
            obj1 = rmfield(obj1, 'connection_init_function');
            file = jsonencode(obj1);
            % compare against current config encoded
            obj2 = dj.config();
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            curr = jsonencode(obj2);
            curr = regexprep(curr,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            testCase.verifyEqual(file, curr);
            assert(~contains(read_data, '[]'));

            delete(fname)
        end
        function testLoad(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % test with subtraction of structs to verify the rest....
            % check load from file
            pkg = what('tests');
            fname = [pkg.path '/test_schemas/test_config.json'];
            % restore config
            dj.config.restore;
            dj.config.save([pkg.path '/test_schemas/default.json']);
            % load into an obj and encode
            read_data = fileread(fname);
            obj1 = jsondecode(read_data);
            defaults = jsondecode(fileread([pkg.path '/test_schemas/default.json']));
            tmp = rmfield(defaults, intersect(fieldnames(defaults), fieldnames(obj1)));
            names = [fieldnames(tmp); fieldnames(obj1)];
            obj1 = orderfields(cell2struct([struct2cell(tmp); struct2cell(obj1)], names, 1));
            obj1 = rmfield(obj1, 'database_host');
            obj1 = rmfield(obj1, 'database_user');
            obj1 = rmfield(obj1, 'database_password');
            obj1 = rmfield(obj1, 'connection_init_function');
            file = jsonencode(obj1);
            % compare against current config encoded
            % load
            dj.config.load(fname);
            obj2 = dj.config();
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            curr = jsonencode(obj2);
            curr = regexprep(curr,'[a-z0-9][A-Z]','${$0(1)}_${lower($0(2))}');
            testCase.verifyEqual(file, curr);
            delete([pkg.path '/test_schemas/default.json']);
            dj.config.restore;

            % check load from file
            pkg = what('tests');
            fname = [pkg.path '/test_schemas/test_config_lite.json'];
            % restore config
            dj.config.restore;
            % load
            dj.config.load(fname);
            % load into an obj and encode
            obj1 = orderfields(dj.internal.Settings.DEFAULTS);
            obj1 = rmfield(obj1, 'databaseHost');
            obj1 = rmfield(obj1, 'databaseUser');
            obj1 = rmfield(obj1, 'databasePassword');
            obj1 = rmfield(obj1, 'connectionInit_function');
            obj1 = rmfield(obj1, 'databaseUse_tls');
            file = jsonencode(obj1);
            % compare against current config encoded
            obj2 = dj.config();
            obj2 = rmfield(obj2, 'databaseHost');
            obj2 = rmfield(obj2, 'databaseUser');
            obj2 = rmfield(obj2, 'databasePassword');
            obj2 = rmfield(obj2, 'connectionInit_function');
            obj2 = rmfield(obj2, 'databaseUse_tls');
            curr = jsonencode(obj2);
            testCase.verifyEqual(file, curr);
            dj.config.restore;
        end
        function testEnv(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % check pull from env vars
            %test after a load
            pkg = what('tests');
            setenv('DJ_INIT', 'select @@version;');
            dj.config.restore;

            c = dj.config('databaseHost');
            testCase.verifyEqual(c, getenv('DJ_HOST'));
            c = dj.config('databaseUser');
            testCase.verifyEqual(c, getenv('DJ_USER'));
            c = dj.config('databasePassword');
            testCase.verifyEqual(c, getenv('DJ_PASS'));
            c = dj.config('connectionInit_function');
            testCase.verifyEqual(c, getenv('DJ_INIT'));

            dj.config.load([pkg.path '/test_schemas/test_config.json']);

            c = dj.config('databaseHost');
            testCase.verifyEqual(c, getenv('DJ_HOST'));
            c = dj.config('databaseUser');
            testCase.verifyEqual(c, getenv('DJ_USER'));
            c = dj.config('databasePassword');
            testCase.verifyEqual(c, getenv('DJ_PASS'));
            c = dj.config('connectionInit_function');
            testCase.verifyEqual(c, getenv('DJ_INIT'));

            dj.config('databaseHost', 'localhost');
            c = dj.config('databaseHost');
            testCase.verifyEqual(c, 'localhost');
            dj.config('databaseUser', 'john');
            c = dj.config('databaseUser');
            testCase.verifyEqual(c, 'john');
            dj.config('databasePassword', 'secure');
            c = dj.config('databasePassword');
            testCase.verifyEqual(c, 'secure');
            dj.config('connectionInit_function', 'SET SESSION sql_mode="TRADITIONAL";');
            c = dj.config('connectionInit_function');
            testCase.verifyEqual(c, 'SET SESSION sql_mode="TRADITIONAL";');

            setenv('DJ_INIT', '');
            dj.config.restore;
        end
    end
end