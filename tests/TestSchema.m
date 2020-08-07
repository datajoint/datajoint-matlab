classdef TestSchema < Prep
    % TestSchema tests related to schemas.
    methods (Test)
        % https://github.com/datajoint/datajoint-matlab/issues/254
        function TestSchema_testUnsupportedDJTypes(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            package = 'University';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);

            University.Message
            c1.query('ALTER TABLE `djtest_university`.`message` CHANGE `dep_id` `dep_id` binary(16) COMMENT '':attach:''');
            delete([testCase.test_root '/test_schemas/+' package '/getSchema.m']);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);
            University.getSchema;
            % in progress...
            % test display
            University.Message
            % test reverse engineering
            % q = University.Message;
            % raw_def = dj.internal.Declare.getDefinition(q);
            % assembled_def = describe(q);
            % [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            % [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            % testCase.verifyEqual(raw_sql,  assembled_sql);
            % test fetch good
            q = University.Message;
            res = q.fetch('msg_id');
            % test fetch bad
            % res = q.fetch('dep_id');
            % test insert
            insert(University.Message, struct( ...
                'msg_id', '1d751e2e-1e74-faf8-4ab4-85fde8ef72be', ...
                'body', 'Great campus!', ...
                'dep_id', 'ter' ...
            ));
            % % test update
        end
    end
end