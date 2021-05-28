classdef TestDeclaration < Prep
    methods (Test)
        %{ Function to test if a table can be inserted with curley brackets in the comments
        %}
        function TestDeclaration_testCurlyBracketComment(testCase)
            packageName = 'Lab';
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
            Lab.Subject

            % Check that the comment is correct
            table = Lab.Subject();
            firstAttributeComment = table.header.attributes.comment;
            assert(strcmp( ...
                firstAttributeComment, ...
                '{subject_id} Comment to test curly bracket'), ...
                'Comment did not get inserted correctly'...
                );
        end
    end
end