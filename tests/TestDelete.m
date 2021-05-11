classdef TestDelete < Prep
    % TestDelete tests delete operations.
    methods (Test)
        function TestDelete_testRenamedDelete(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/362
            package = 'Company';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,...
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_company']);

            inserti(Company.Employee, {'raphael'; 'shan'; 'chris'; 'thinh'});
            inserti(Company.Duty, {'schedule1', 'shan'; 'schedule2', 'raphael'});
            testCase.verifyEqual(length(fetch(Company.Employee)), 4);
            testCase.verifyEqual(length(fetch(Company.Duty)), 2);
            disp(Company.Employee);
            disp(Company.Duty);

            del(Company.Employee & 'employee_id="shan"');
            disp(Company.Employee);
            disp(Company.Duty);
            testCase.verifyEqual(length(fetch(Company.Employee)), 3);
            testCase.verifyEqual(length(fetch(Company.Duty)), 1);
        end
    end
end