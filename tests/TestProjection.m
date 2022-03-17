classdef TestProjection < Prep
    % TestProjection tests use of q.proj(...).
    methods (Test)
        function TestProjection_testDateConversion(testCase)
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

            dj.config('safemode', 0);
            drop(University.Student);
        end
        function TestProjection_testRenameSameKey(testCase)
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

            q = proj(University.Student & 'first_name = "Raphael"', 'student_id->faculty_id', 'student_id->school_id');
            testCase.verifyEqual(q.fetch('faculty_id', 'school_id'), struct('faculty_id', 10, 'school_id', 10));

            dj.config('safemode', 0);
            drop(University.Student);
        end
    end
end