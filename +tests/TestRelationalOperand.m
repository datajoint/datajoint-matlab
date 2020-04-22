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

            new_value = [];
            q.update('date', new_value);
            res = mym(['select date from `' testCase.PREFIX ...
                '_university`.`all` where id=2 and date is null;']);
            testCase.verifyEqual(length(res.date), 1);

            new_value = '2020-04-14';
            q.update('date', new_value);
            res = mym(['select date from `' testCase.PREFIX ...
                '_university`.`all` where id=2 and date like ''' new_value ''';']);
            testCase.verifyEqual(length(res.date), 1);

            q.update('date');
            res = mym(['select date from `' testCase.PREFIX ...
                '_university`.`all` where id=2 and date is null;']);
            testCase.verifyEqual(length(res.date), 1);
        end
        function TestRelationalOperand_testUpdateString(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % related https://github.com/datajoint/datajoint-matlab/issues/211
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.All, struct( ...
                'id', 3, ...
                'string', 'normal' ...
            ));
            q = University.All & 'id=3';

            new_value = '';
            q.update('string', new_value);
            res = mym(['select string from `' testCase.PREFIX ...
                '_university`.`all` where id=3 and string like ''' new_value ''';']);
            testCase.verifyEqual(length(res.string), 1);

            new_value = ' ';
            q.update('string', new_value);
            res = mym(['select string from `' testCase.PREFIX ...
                '_university`.`all` where id=3 and string like ''' new_value ''';']);
            testCase.verifyEqual(length(res.string), 1);

            new_value = [];
            q.update('string', new_value);
            res = mym(['select string from `' testCase.PREFIX ...
                '_university`.`all` where id=3 and string is null;']);
            testCase.verifyEqual(length(res.string), 1);

            new_value = 'diff';
            q.update('string', new_value);
            res = mym(['select string from `' testCase.PREFIX ...
                '_university`.`all` where id=3 and string like ''' new_value ''';']);
            testCase.verifyEqual(length(res.string), 1);

            q.update('string');
            res = mym(['select string from `' testCase.PREFIX ...
                '_university`.`all` where id=3 and string is null;']);
            testCase.verifyEqual(length(res.string), 1);
        end
    end
end