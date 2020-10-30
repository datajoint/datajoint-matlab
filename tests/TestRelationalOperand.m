classdef TestRelationalOperand < Prep
    % TestRelationalOperand tests relational operations.
    methods (Test)
        function TestRelationalOperand_testFkOptions(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % https://github.com/datajoint/datajoint-matlab/issues/110
            package = 'Lab';

            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);

            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_lab']);

            insert(Lab.Subject, {
               0, '2020-04-02';
               1, '2020-05-03';
               2, '2020-04-22';
            });
            insert(Lab.Rig, struct( ...
                'rig_manufacturer', 'Lenovo', ...
                'rig_model', 'ThinkPad', ...
                'rig_note', 'blah' ...
            ));
            % insert as renamed foreign keys
            insert(Lab.ActiveSession, struct( ...
                'subject_id', 0, ...
                'session_rig_class', 'Lenovo', ...
                'session_rig_id', 'ThinkPad' ...
            ));
            testCase.verifyEqual(fetch1(Lab.ActiveSession, 'session_rig_class'), 'Lenovo');
            % insert null for rig (subject reserved, awaiting rig assignment)
            insert(Lab.ActiveSession, struct( ...
                'subject_id', 1 ...
            ));
            testCase.verifyTrue(isempty(fetch1(Lab.ActiveSession & 'subject_id=1', ...
                                               'session_rig_class')));
            % insert duplicate rig (rigs should only be active once per
            % subject)
            try
                insert(Lab.ActiveSession, struct( ...
                    'subject_id', 2, ...
                    'session_rig_class', 'Lenovo', ...
                    'session_rig_id', 'ThinkPad' ...
                ));
                error('Unique index fail...');
            catch ME
                if ~contains(ME.message, 'Duplicate entry')
                    rethrow(ME);
                end
            end
            % verify reverse engineering (TBD)
            q = Lab.ActiveSession;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            % [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            % testCase.verifyEqual(raw_sql,  assembled_sql);
        end
    end
end