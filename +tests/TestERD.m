classdef TestERD < tests.Prep
    % TestERD tests unusual ERD scenarios.
    methods (Test)
        function testDraw(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            insert(University.Student, {
               0   'John'   'Smith'  '2019-09-19 16:50'
               1   'Phil'   'Howard' '2019-04-30 12:34:56' 
               2   'Ben'   'Goyle'   '2019-05-11'
            });

            dj.ERD(University.Student)
        end
    end
end