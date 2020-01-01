classdef TestProjection < tests.Prep
    % TestProjection tests use of q.proj(...).
    methods (Test)
        function testDateConversion(testCase)
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
               10   'Raphael'   'Guzman' datestr(datetime, 'yyyy-mm-dd HH:MM:SS')
               11   'Shan'   'Shen' '2019-11-25 12:34:56'
               12   'Joe'   'Schmoe' '2018-01-24 14:34:16'
            });

            q = proj(University.Student, 'date(enrolled)->enrolled_date') & ...
                'enrolled_date="2018-01-24"';

            res = q.fetch1('enrolled_date');
            testCase.verifyEqual(res,  '2018-01-24');
        end
    end
end