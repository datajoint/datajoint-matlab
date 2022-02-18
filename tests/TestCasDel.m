classdef TestCasDel < Prep
    % TestCasDel tests delete operations.
    methods (Test)
        function TestCasDel_testCasDelete(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https:%github.com/datajoint/datajoint-matlab/issues/379
            dj.config('safemode', false);
            package = 'TestLab';

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_testlab']);

            users = [{'user0', 
                    'user1', 
                    'user2'}]

            insert(TestLab.User, users)

            duty = [{'2020-01-01','user0','user1'},
                    {'2020-12-31','user1','user2'}]

            insert(TestLab.Duty, duty)

            TestLab.User()

            TestLab.Duty()

            key.user_id = 'user0'
            del(TestLab.User & key)
        end
    end
end