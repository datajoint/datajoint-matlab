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
        function TestDelete_testTwoFKOnePK(testCase) %runtests('Main/TestDelete_testTwoFKOnePK')
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https:%github.com/datajoint/datajoint-matlab/issues/379
            dj.config('safemode', false);
            package = 'TestLab';

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_testlab']);

            users = [{'user0'; 'user1'; 'user2'}];

            insert(TestLab.User, users);

            duty = [{'2020-01-01','user0','user1'},
                    {'2020-12-31','user1','user2'}];

            insert(TestLab.Duty, duty);

            key.user_id = 'user0';
            del(TestLab.User & key);

            testCase.verifyEqual(length(fetch(TestLab.User & 'user_id != "user0"')), 2);
            testCase.verifyEqual(length(fetch(TestLab.Duty & 'duty_second != "user0"')), 1);
        end
%         function TestDelete_testMultiple(testCase)
%             st = dbstack;
%             disp(['---------------' st(1).name '---------------']);
%             % https:%github.com/datajoint/datajoint-matlab/issues/379
%             dj.config('safemode', false);
%             package = 'TestMultiple';

%             dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
%                 [testCase.PREFIX '_testmultiple']);

%             users = [{'user0', 'user1', 'user2'; 'user3', 'user4', 'user5'; 'user6', 'user7', 'user8'}];

%             insert(TestMultiple.User, users);

%             lab = [{'2020-01-01','user0','user1', 'user2'},
%                     {'2020-12-30','user3','user4', 'user5'},
%                     {'2020-12-31','user6','user7', 'user8'}];

%             insert(TestMultiple.Lab, lab);

%             TestMultiple.User
%             TestMultiple.Lab

%             key.user_x = 'user0';
%             del(TestMultiple.User & key);

%             TestMultiple.User
%             TestMultiple.Lab

%             testCase.verifyEqual(length(fetch(TestMultiple.User & 'user_x != "user0"')), 2);
%             testCase.verifyEqual(length(fetch(TestMultiple.Lab & 'lab1 != "user0"')), 2);
%         end
    end
end