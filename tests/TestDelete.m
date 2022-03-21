classdef TestDelete < Prep
    % TestDelete tests delete operations.
    methods (Test)
        function TestDelete_testRenamedDelete(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/362
            dj.config('safemode', false);
            package = 'Company';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,...
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_company']);

            inserti(Company.Employee, {'raphael', 2019; 'shan', 2018; 'chris', 2018; ...
                                       'thinh', 2019});
            inserti(Company.Duty, {'schedule1', 'shan', 2018; 'schedule2', 'raphael', 2019});
            inserti(Company.Machine, {'shan', 2018, 'abc1023'; 'raphael', 2019, 'xyz9876'});
            testCase.verifyEqual(length(fetch(Company.Employee)), 4);
            testCase.verifyEqual(length(fetch(Company.Duty)), 2);
            testCase.verifyEqual(length(fetch(Company.Machine)), 2);

            del(Company.Employee & 'employee_id="shan"');

            testCase.verifyEqual(length(fetch(Company.Employee)), 3);
            testCase.verifyEqual(...
                length(fetch(Company.Employee & struct('employee_id', 'shan'))), 0);
            testCase.verifyEqual(length(fetch(Company.Duty)), 1);
            testCase.verifyEqual(...
                length(fetch(Company.Duty & struct('monday_on_call', 'shan'))), 0);
            testCase.verifyEqual(length(fetch(Company.Machine)), 1);
            testCase.verifyEqual(...
                length(fetch(Company.Machine & struct('employee_id', 'shan'))), 0);
        end
        function TestDelete_testThreeFKOnePK(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https:%github.com/datajoint/datajoint-matlab/issues/379
            dj.config('safemode', false);
            package = 'TestLab';

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_testlab']);

            users = [{'user0'; 'user1'; 'user2'; 'user3'}];

            insert(TestLab.User, users);

            duty = [{'2020-01-01','user0','user2', 'user1'},
                    {'2020-01-02','user0','user1', 'user2'},
                    {'2020-12-30','user1','user2', 'user0'},
                    {'2020-12-31','user0','user2', 'user3'}];

            insert(TestLab.Duty, duty);

            key.user_id = 'user1';
            del(TestLab.User & key);

            testCase.verifyEqual(length(fetch(TestLab.User)), 3);
            testCase.verifyEqual(length(fetch(TestLab.Duty)), 1);
            testCase.verifyEqual(length(fetch(TestLab.User & 'user_id = "user1"')), 0);
            testCase.verifyEqual(length(fetch(TestLab.Duty & 'duty_first = "user1" OR duty_second = "user1" OR duty_third = "user1"')), 0);
        end
    end
end