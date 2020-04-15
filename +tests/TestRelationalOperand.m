classdef TestRelationalOperand < tests.Prep
    % TestRelationalOperand tests relational operations.
    methods (Test)
        function TestRelationalOperand_testUpdateDate(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/211
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 2, ...
                'date', '2019-12-20' ...
            ));
            q = University.All & 'id=2';

            new_value = '';
            q.update('date', new_value);
            testCase.verifyEqual(q.fetch1('date'),  new_value);

            new_value = '2020-04-14';
            q.update('date', new_value);
            testCase.verifyEqual(q.fetch1('date'),  new_value);

            q.update('date');
            testCase.verifyEqual(q.fetch1('date'),  '');
        end
    end
end