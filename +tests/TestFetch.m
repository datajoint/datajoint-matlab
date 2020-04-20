classdef TestFetch < tests.Prep
    % TestFetch tests typical insert/fetch scenarios.
    methods (Test)
        function TestFetch_testVariousDatatypes(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 2, ...
                'string', 'test', ...
                'date', '2019-12-17 13:38', ...
                'number', 3.213, ...
                'blob', [1, 2; 3, 4] ...
            ));

            q = University.All & 'id=2';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  2);
            testCase.verifyEqual(res(1).string,  'test');
            testCase.verifyEqual(res(1).date,  '2019-12-17 13:38:00');
            testCase.verifyEqual(res(1).number,  3.213);
            testCase.verifyEqual(res(1).blob,  [1, 2; 3, 4]);
        end
        function TestFetch_testBlobScalar(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/217
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 3, ...
                'string', 'nothing', ...
                'date', '2020-03-17 20:38', ...
                'number', 9.7, ...
                'blob', 1 ...
            ));

            q = University.All & 'id=3';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).string,  'nothing');
        end
        function TestFetch_testNullable(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % related to % https://github.com/datajoint/datajoint-matlab/issues/211
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 4 ...
            ));

            q = University.All & 'id=4';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  4);
            testCase.verifyEqual(res(1).string,  '');
            testCase.verifyEqual(res(1).date,  '');
            testCase.verifyEqual(res(1).number,  NaN);
            testCase.verifyEqual(res(1).blob,  '');

            insert(University.All, struct( ...
                'id', 5, ...
                'string', '', ...
                'date', '', ...
                'number', [], ...
                'blob', [] ...
            ));

            q = University.All & 'id=5';
            res = q.fetch('*');

            testCase.verifyEqual(res(1).id,  5);
            testCase.verifyEqual(res(1).string,  '');
            testCase.verifyEqual(res(1).date,  '');
            testCase.verifyEqual(res(1).number,  NaN);
            testCase.verifyEqual(res(1).blob,  '');
        end
        function TestFetch_testDescribe(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            q = University.All;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            assembled_sql = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
        end
        function TestFetch_testString(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            id = 1;
            correct_value = 'n';
            null_value = [];
            wrong_value = 5;
            incr = @(x) [x 'o'];
            table = University.String;
            
            value_incr = correct_value;
            num_attr = length(table.header.notBlobs);
            
            if ischar(correct_value)
                v = cell(1, num_attr);
                v(:) = {correct_value};
            else
                v = num2cell(repmat(correct_value,1,num_attr));
            end
            
            base_value = cell2struct(v, table.header.notBlobs, 2);
            base_value.id = id;
            insert(table, base_value);
            first = (table & struct('id', id));
            first = first.fetch('*');
            
            for i = 2:num_attr
                attr = table.header.attributes(i);
                
                % check original value
                testCase.verifyEqual(first(1).(attr.name),  correct_value);
                
                % wrong value
                id = id + 1;
                value_incr = incr(value_incr);
                if ischar(correct_value)
                    v = cell(1, num_attr);
                    v(:) = {value_incr};
                    curr_value = cell2struct(v, table.header.notBlobs, 2);
                else
                    curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), table.header.notBlobs, 2);
                end
                curr_value.id = id;
                curr_value.(attr.name) = wrong_value;
                try
                    insert(table, curr_value);
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:Mismatch')
                        rethrow(ME);
                    end
                end
                
                % null value
                id = id + 1;
                value_incr = incr(value_incr);
                if ischar(correct_value)
                    v = cell(1, num_attr);
                    v(:) = {value_incr};
                    curr_value = cell2struct(v, table.header.notBlobs, 2);
                else
                    curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), table.header.notBlobs, 2);
                end
                curr_value.id = id;
                curr_value.(attr.name) = null_value;
                try
                    insert(table, curr_value);
                catch ME
                    if attr.isnullable || ~strcmp(ME.identifier,'DataJoint:DataType:NotNullable')
                        rethrow(ME);
                    end
                end
                
                % default value
                id = id + 1;
                curr_value = base_value;
                curr_value.id = id;
                curr_value = rmfield(curr_value, attr.name);
                try
                    insert(University.Integer, curr_value);
                catch ME
                    if ~isempty(attr.default) || ~contains(ME.message,'doesn''t have a default value')
                        rethrow(ME);
                    end
                end
            end
            
            
%             strings = cell(1, num_attr);
%             strings(:) = {wrong_value};
%             value = cell2struct(strings, table.header.notBlobs, 2);
%             value.id = id + 1;
%             insert(University.Integer, value);
            
%             strings = cell(1, num_attr);
%             strings(:) = {wrong_value};
%             value = cell2struct(strings, table.header.notBlobs, 2);
%             value.id = id + 1;
%             insert(University.Integer, value);
            
        end
        function TestFetch_testInteger(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            id = 1;
            correct_value = 5;
            null_value = NaN;
            wrong_value = 'wrong';
            incr = @(x) x + 1;
            
            value_incr = correct_value;
            
            table = University.Integer;
            num_attr = length(table.header.notBlobs);
            
            base_value = cell2struct(num2cell(repmat(correct_value,1,num_attr)), table.header.notBlobs, 2);
            base_value.id = id;
            insert(University.Integer, base_value);
            first = (table & struct('id', id));
            first = first.fetch('*');
            
            for i = 2:num_attr
                attr = table.header.attributes(i);
                
                % check original value
                testCase.verifyEqual(first(1).(attr.name),  correct_value);
                
                % wrong value
                id = id + 1;
                value_incr = incr(value_incr);
                curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), table.header.notBlobs, 2);
                curr_value.id = id;
                curr_value.(attr.name) = wrong_value;
                try
                    insert(University.Integer, curr_value);
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:Mismatch')
                        rethrow(ME);
                    end
                end
                
                % null value
                id = id + 1;
                value_incr = incr(value_incr);
                curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), table.header.notBlobs, 2);
                curr_value.id = id;
                curr_value.(attr.name) = null_value;
                try
                    insert(University.Integer, curr_value);
                catch ME
                    if attr.isnullable || ~strcmp(ME.identifier,'DataJoint:DataType:NotNullable')
                        rethrow(ME);
                    end
                end
                
%                 % default value
%                 id = id + 1;
%                 curr_value = base_value;
%                 curr_value.id = id;
%                 curr_value = rmfield(curr_value, attr.name);
%                 try
%                     insert(University.Integer, curr_value);
%                 catch ME
%                     if ~isempty(attr.default) || ~contains(ME.message,'doesn''t have a default value')
%                         rethrow(ME);
%                     end
%                 end
            end
            
            
%             strings = cell(1, num_attr);
%             strings(:) = {wrong_value};
%             value = cell2struct(strings, table.header.notBlobs, 2);
%             value.id = id + 1;
%             insert(University.Integer, value);
            
%             strings = cell(1, num_attr);
%             strings(:) = {wrong_value};
%             value = cell2struct(strings, table.header.notBlobs, 2);
%             value.id = id + 1;
%             insert(University.Integer, value);
            
        end
    end
end