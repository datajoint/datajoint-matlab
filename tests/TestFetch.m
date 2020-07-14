classdef TestFetch < Prep
    % TestFetch tests typical insert/fetch scenarios.
    methods (Static)
        function TestFetch_Generic(testCase, id, correct_value, null_value, wrong_value, ...
                incr, table)
            % related https://github.com/datajoint/datajoint-matlab/issues/217
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
                    curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), ...
                        table.header.notBlobs, 2);
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
                    curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), ...
                        table.header.notBlobs, 2);
                end
                curr_value.id = id;
                curr_value.(attr.name) = null_value;
                try
                    insert(table, curr_value);
%                     q = table & ['id=' num2str(id)];
%                     testCase.verifyEqual(q.fetch(attr.name).(attr.name), null_value);
                    res = mym(['select ' attr.name ' from `' testCase.PREFIX ...
                        '_university`.`' table.plainTableName '` where id=' num2str(id) ...
                        ' and ' attr.name ' is ' 'NULL' ';']);
                    testCase.verifyEqual(length(res.(attr.name)), 1);
                catch ME
                    if attr.isnullable || ~strcmp(ME.identifier, ...
                            'DataJoint:DataType:NotNullable')
                        rethrow(ME);
                    end
                end
                
                % default value
                id = id + 1;
                value_incr = incr(value_incr);
                if ischar(correct_value)
                    v = cell(1, num_attr);
                    v(:) = {value_incr};
                    curr_value = cell2struct(v, table.header.notBlobs, 2);
                else
                    curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), ...
                        table.header.notBlobs, 2);
                end
                curr_value.id = id;
                curr_value = rmfield(curr_value, attr.name);
                try
                    insert(table, curr_value);
                    if ischar(attr.default) && isempty(attr.default)
                        res = mym(['select ' attr.name ' from `' testCase.PREFIX ...
                            '_university`.`' table.plainTableName '` where id=' num2str(id) ...
                            ' and ' attr.name ' is ' 'null' ';']);
                    elseif attr.isString
                        res = mym(['select ' attr.name ' from `' testCase.PREFIX ...
                            '_university`.`' table.plainTableName '` where id=' num2str(id) ...
                            ' and ' attr.name ' like ' ['''' attr.default ''''] ';']);
                    else
                        res = mym(['select ' attr.name ' from `' testCase.PREFIX ...
                            '_university`.`' table.plainTableName '` where id=' num2str(id) ...
                            ' and ' attr.name ' like ' attr.default ';']);
                    end
                    testCase.verifyEqual(length(res.(attr.name)), 1);
                catch ME
                    if ~isempty(attr.default) || ~contains(ME.message, ...
                            'doesn''t have a default value')
                        rethrow(ME);
                    end
                end
                
                % non-unique value
%                 id = id + 1;
%                 value_incr = incr(value_incr);
%                 if ischar(correct_value)
%                     v = cell(1, num_attr);
%                     v(:) = {value_incr};
%                     curr_value = cell2struct(v, table.header.notBlobs, 2);
%                 else
%                     curr_value = cell2struct(num2cell(repmat(value_incr,1,num_attr)), ...
%                         table.header.notBlobs, 2);
%                 end
%                 curr_value.id = id;
%                 curr_value.(attr.name) = correct_value;
%                 try
%                     insert(table, curr_value);
%                     res = mym(['select ' attr.name ' from `' testCase.PREFIX ...
%                         '_university`.`' table.plainTableName '` where id=' num2str(id) ...
%                         ' and ' attr.name '=' ['''' correct_value ''''] ';']);
%                     testCase.verifyEqual(length(res.(attr.name)), 1);
%                 catch ME
%                     if contains(attr.name, 'nounq') || ~contains(ME.message, ...
%                             'Duplicate entry')
%                         rethrow(ME);
%                     end
%                 end
            end
        end
    end
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
                'string', 'lteachen', ...
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
                'date', [], ...
                'number', NaN, ...
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
            
            TestFetch.TestFetch_Generic(testCase, 1, 'n', [], 5, ...
                @(x) strcat(x, 'o'), University.String);
        end
        function TestFetch_testDate(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);
            
            TestFetch.TestFetch_Generic(testCase, 1, '2020-01-01', [], 5, ...
                @(x) datestr(addtodate(datenum(x), 1, 'day'), 'yyyy-mm-dd'), University.Date);
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
            
            TestFetch.TestFetch_Generic(testCase, 1, 2, NaN, 'wrong', ...
                @(x) x + 1, University.Integer);        
        end
        function TestFetch_testFloat(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);
            
            TestFetch.TestFetch_Generic(testCase, 1, 1.01, NaN, 'wrong', ...
                @(x) x + 0.01, University.Float);        
        end
    end
end