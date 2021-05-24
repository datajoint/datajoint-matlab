classdef TestTableDecleration < Prep
    methods (Test)
        %{ Function to test if a table can be inserted with curley brackets in the comments
        %}
        function TestTableDecleration_testCurleyBracketComment(testCase)
            packageName = 'Decleration';
            lowerPackageName = lower(packageName);
            % Create the connection
            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password, '', true);

            % Create the schema
            dj.createSchema(packageName, [testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_' lowerPackageName]);

            % Initialize the table
            Decleration.CurleyBracketCommentTable

            % Check that the comment is correct
            table = Decleration.CurleyBracketCommentTable();
            firstAttributeComment = table.header.attributes.comment;
            assert(strcmp(firstAttributeComment, '{username}_{subject_nickname}'), 'Comment did not get inserted correctly');
        end
    end
end