classdef TestSchema < Prep
    % TestSchema tests related to schemas.
    methods (Test)
        % https://github.com/datajoint/datajoint-matlab/issues/254
        function TestSchema_testUnsupportedDJTypes(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % setup
            dj.config.restore;
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
            dj.config('safemode', false);
            dj.config('stores',struct(store_name, struct('protocol', 'file', 'location', ...
                store_dir)));
            id = 2;
            External.Document
            c1.query(['insert into `' testCase.PREFIX '_' lower(package) '`.`~external_' ...
                store_name '`(hash,size,attachment_name,filepath,contents_hash) values ' ...
                '(X''1d751e2e1e74faf84ab485fde8ef72be'', 1, ''attach_name'', ''filepath'',' ...
                ' X''1d751e2e1e74faf84ab485fde8ef72ca''),' ...
                '(X''1d751e2e1e74faf84ab485fde8ef72bf'', 2, ''attach_name'', ''filepath'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72cb'')']);
            c1.query(['insert into `' testCase.PREFIX '_' lower(package) '`.`#document` ' ...
                'values (' num2str(id) ', ''raphael'', ''hello'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72be'',' ...
                'X''1d751e2e1e74faf84ab485fde8ef72bf'')']);
            delete([testCase.test_root '/test_schemas/+' package '/getSchema.m']);
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_' lower(package)]);
            schema = External.getSchema;
            q = schema.v.Document & ['document_id=' num2str(id)];
            % display
            queryPreview = evalc('q');
            queryPreview = splitlines(queryPreview);
            recordPreview = queryPreview(end-4);
            recordPreview = strsplit(recordPreview{1});
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x,'''=BLOB='''), ...
                recordPreview(4:end-1))));
            % reverse engineering
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            testCase.verifyEqual(raw_sql,  assembled_sql);
            % fetch good
            testCase.verifyEqual(q.fetch1('document_id'),  id);
            % fetch bad
            for c = {'document_data1', 'document_data2', 'document_data3'}
                try
                    res = q.fetch(char(c{1}));
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:NotYetSupported')
                        rethrow(ME);
                    end
                end
            end
            % insert bad
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
            % update good
            new_name = 'peter';
            update(q, 'document_name', new_name);
            testCase.verifyEqual(q.fetch1('document_name'),  new_name);
            % update bad
            for c = {'document_data1', 'document_data2', 'document_data3'}
                try
                    update(q, char(c{1}), 'this');
                catch ME
                    if ~strcmp(ME.identifier,'DataJoint:DataType:NotYetSupported')
                        rethrow(ME);
                    end
                end
            end
            % clean up
            schema.dropQuick;
            rmdir(store_dir, 's');
        end
        function TestSchema_testNew(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % setup
            dj.config.restore;
            dj.config('safemode', false);
            dj.new('new.Student', 'M', pwd , 'djtest_new');
            rmdir('+new', 's');
        end
        function TestSchema_testVirtual(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            % setup
            dj.config.restore;
            package = 'Lab';
            c1 = dj.conn(...
                testCase.CONN_INFO.host, ...
                testCase.CONN_INFO.user, ...
                testCase.CONN_INFO.password,'',true);
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_' lower(package)]);
            Lab.SessionAnalysis()
            schema = dj.Schema(c1, package, [testCase.PREFIX '_' lower(package)]);
            schema.v.SessionAnalysis()
        end
    end
end