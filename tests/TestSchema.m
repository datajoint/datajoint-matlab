classdef TestSchema < Prep
    % TestSchema tests related to schemas.
    methods (Test)
        % https://github.com/datajoint/datajoint-matlab/issues/254
        function TestSchema_testUnsupportedDJTypes(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % setup
            package = 'External';
            c1 = dj.conn(...
                testCase.CONN_INFO.host,... 
                testCase.CONN_INFO.user,...
                testCase.CONN_INFO.password,'',true);
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_' lower(package)]);
            store_dir = '/tmp/fake';
            store_name = 'main';
            mkdir(store_dir);
            dj.config('stores',struct(store_name, struct('protocol', 'file', 'location', ...
                store_dir)));
            id = 2;
            % schema = External.getSchema;
            schema = dj.Schema(c1, package, [testCase.PREFIX '_' lower(package)]);
            schema.v
            q = schema.v.Document & ['document_id=' num2str(id)]
            c1.query(['insert into `' testCase.PREFIX '_' lower(package) '`.`~external_' ...
                store_name '`(hash,size,attachment_name,filepath,contents_hash) values ' ...
                '(X''1d751e2e1e74faf84ab485fde8ef72be'', 1, ''attach_name'', ''filepath'',' ...
                ' X''1d751e2e1e74faf84ab485fde8ef72ca''),' ...
                '(X''1d751e2e1e74faf84ab485fde8ef72bf'', 2, ''attach_name'', ''filepath'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72cb'')']);
            c1.query(['insert into `' testCase.PREFIX '_' lower(package) '`.`document` ' ...
                'values (' num2str(id) ', ''raphael'', ''hello'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72be'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72bf'')']);
            % display test
            q
            % test reverse engineering
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
            % test fetch good
            testCase.verifyEqual(q.fetch1('document_id'),  id);
            % test fetch bad
            for c = ["document_data1", "document_data2", "document_data3"]
                try
                    res = q.fetch(char(c));
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:NotYetSupported')
                        rethrow(ME);
                    end
                end
            end
            % test insert bad
            try
                insert(q, struct( ...
                    'document_id', 3, ...
                    'document_name', 'john', ...
                    'document_data1', 'this', ...
                    'document_data2', 'won''t', ...
                    'document_data3', 'work' ...
                ));
            catch ME
                if ~strcmp(ME.identifier,'DataJoint:DataType:NotYetSupported')
                    rethrow(ME);
                end
            end
            % test update good
            new_name = 'peter';
            update(q, 'document_name', new_name);
            testCase.verifyEqual(q.fetch1('document_name'),  new_name);
            % test update bad
            for c = ["document_data1", "document_data2", "document_data3"]
                try
                    update(q, char(c), 'this');
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:NotYetSupported')
                        rethrow(ME);
                    end
                end
            end
            % clean up
            rmdir(store_dir);
            dj.config.restore;
            % display
            % v
            % external table included in schema.tableNames
            % external table included in schema.classNames
        end
        % function TestSchema_testUnsupportedDJTypes(testCase)
        %     st = dbstack;
        %     disp(['---------------' st(1).name '---------------']);
        %     package = 'University';

        %     c1 = dj.conn(...
        %         testCase.CONN_INFO.host,... 
        %         testCase.CONN_INFO.user,...
        %         testCase.CONN_INFO.password,'',true);

        %     dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
        %         [testCase.PREFIX '_university']);

        %     University.Message
        %     c1.query('ALTER TABLE `djtest_university`.`message` CHANGE `dep_id` `dep_id` binary(16) COMMENT '':attach:''');
        %     delete([testCase.test_root '/test_schemas/+' package '/getSchema.m']);

        %     dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
        %         [testCase.PREFIX '_university']);
        %     University.getSchema;
        %     % in progress...
        %     % test display
        %     University.Message
        %     % test reverse engineering
        %     % q = University.Message;
        %     % raw_def = dj.internal.Declare.getDefinition(q);
        %     % assembled_def = describe(q);
        %     % [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
        %     % [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
        %     % testCase.verifyEqual(raw_sql,  assembled_sql);
        %     % test fetch good
        %     q = University.Message;
        %     res = q.fetch('msg_id');
        %     % test fetch bad
        %     % res = q.fetch('dep_id');
        %     % test insert
        %     % insert(University.Message, struct( ...
        %     %     'msg_id', '1d751e2e-1e74-faf8-4ab4-85fde8ef72be', ...
        %     %     'body', 'Great campus!', ...
        %     %     'dep_id', 'ter' ...
        %     % ));
        %     % % test update
        % end
    end
end