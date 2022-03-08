classdef TestExternalFile < Prep
    % TestExternalFile tests scenarios related to external file store.
    methods (Static)
        function TestExternalFile_checks(test_instance, store, cache)
            % load config
            pkg_path = test_instance.test_root;
            ext_root = strrep(test_instance.external_file_store_root, '\', '/');
            dj.config.load([strrep(pkg_path, '\', '/') '/test_schemas/store_config.json']);
            dj.config(['stores.' store '.location'], strrep(dj.config(...
                ['stores.' store '.location']), '{{external_file_store_root}}', ...
                ext_root));
            dj.config('stores.main', dj.config(['stores.' store]));
            dj.config(cache, [ext_root '/cache']);
            % create location/cache directories
            mkdir(dj.config(cache));
            if strcmp(dj.config('stores.main.protocol'), 'file')
                mkdir(dj.config('stores.main.location'));
            elseif strcmp(dj.config('stores.main.protocol'), 's3')
                if any(strcmp('secure', fieldnames(dj.config('stores.main')))) && ...
                        dj.config('stores.main.secure')
                    dj.config('stores.main.endpoint', strrep(...
                        test_instance.S3_CONN_INFO.endpoint, ':9000', ':443'));
                else
                    dj.config('stores.main.endpoint', test_instance.S3_CONN_INFO.endpoint);
                end
                dj.config('stores.main.access_key', test_instance.S3_CONN_INFO.access_key);
                dj.config('stores.main.secret_key', test_instance.S3_CONN_INFO.secret_key);
                dj.config('stores.main.bucket', test_instance.S3_CONN_INFO.bucket);
            end
            % create schema
            package = 'External';
            dj.createSchema(package,[test_instance.test_root '/test_schemas'], ...
                [test_instance.PREFIX '_external']);
            % test value
            rng(5);
            test_val1 = floor(rand(1,3)*100);
            % insert
            insert(External.Dimension, struct( ...
                'dimension_id', 4, ...
                'dimension', test_val1 ...
            ));
            % check that external tables are loaded on new schema objs if they already exist
            delete([test_instance.test_root '/test_schemas' '/+' package '/getSchema.m']);
            dj.createSchema(package,[test_instance.test_root '/test_schemas'], ...
                [test_instance.PREFIX '_external']);
            schema = External.getSchema;
            % fetch
            schema.tableNames.remove('External.Dimension');
            q = External.Dimension & 'dimension_id=4';
            res = q.fetch('dimension');
            value_check = res(1).dimension;
            test_instance.verifyEqual(value_check,  test_val1);
            % check subfolding
            packed_cell = mym('serialize {M}', test_val1);
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            uuid_path = schema.external.table('main').make_uuid_path(uuid, '');
            if strcmp(dj.config('stores.main.protocol'), 'file')
                subfold_path = strrep(uuid_path, dj.config('stores.main.location'), '');
            elseif strcmp(dj.config('stores.main.protocol'), 's3')
                subfold_path = strrep(uuid_path, ['/' dj.config('stores.main.bucket') ...
                    '/' dj.config('stores.main.location')], '');
            end
            subfold_path = strrep(subfold_path, ['/' schema.dbname '/'], '');
            subfold_cell = strsplit(subfold_path, '/');
            if length(subfold_cell) > 1
                subfold_cell = subfold_cell(1:end-1);
                subfold_path = ['/' strjoin(subfold_cell, '/')];
            else
                subfold_cell = {};
                subfold_path = '';
            end
            test_instance.verifyEqual(cellfun(@(x) length(x), subfold_cell)', ...
                schema.external.table('main').spec.type_config.subfolding);
            % delete value to rely on cache
            schema.external.table('main').spec.remove_object(uuid_path);
            res = q.fetchn('dimension');
            value_check = res{1};
            test_instance.verifyEqual(value_check,  test_val1);
            % populate
            populate(External.Image);
            q = External.Image & 'dimension_id=4';
            res = q.fetch1('img');
            value_check = res;
            test_instance.verifyEqual(size(value_check),  test_val1);
            % check used and unused
            test_instance.verifyTrue(schema.external.table('main').used.count==2);
            test_instance.verifyTrue(schema.external.table('main').unused.count==0);
            % delete from Dimension
            del(External.Dimension);
            % check children
            q = External.Image;
            test_instance.verifyTrue(q.count==0);
            % check used and unused
            test_instance.verifyTrue(schema.external.table('main').used.count==0);
            test_instance.verifyTrue(schema.external.table('main').unused.count==2);
            % check delete from external
            schema.external.table('main').delete(true, '');
            if strcmp(dj.config('stores.main.protocol'), 'file')
                test_instance.verifyEqual(lastwarn,  ['File ''' ...
                    dj.config('stores.main.location') '/' schema.dbname subfold_path '/' ...
                    uuid ''' not found.']);
            end
            % reverse engineer
            q = External.Dimension;
            raw_def = dj.internal.Declare.getDefinition(q);
            assembled_def = describe(q);
            [raw_sql, ~] = dj.internal.Declare.declare(q, raw_def);
            [assembled_sql, ~] = dj.internal.Declare.declare(q, assembled_def);
            test_instance.verifyEqual(assembled_sql, raw_sql);
            % drop table
            drop(External.Dimension);
            % check used and unused
            test_instance.verifyTrue(schema.external.table('main').used.count==0);
            test_instance.verifyTrue(schema.external.table('main').unused.count==0);
            % remove external storage content
            if ispc
                [status,cmdout] = system(['rmdir /Q /s "' ...
                    test_instance.external_file_store_root '"']);
            else
                [status,cmdout] = system(['rm -R ' ...
                    test_instance.external_file_store_root]);
            end
            % Remove previous mapping
            schema.external.tables = struct();
            % drop database
            schema.conn.query(['DROP DATABASE `' test_instance.PREFIX '_external`']);
            dj.config.restore;
        end
    end
    methods (Test)
        function TestExternalFile_testLocal(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            TestExternalFile.TestExternalFile_checks(testCase, 'new_local', 'blobCache');
        end
        function TestExternalFile_testLocalDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            TestExternalFile.TestExternalFile_checks(testCase, 'new_local_default', ...
                'blobCache');
        end
        function TestExternalFile_testBackward(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            TestExternalFile.TestExternalFile_checks(testCase, 'local', 'cache');
        end
        function TestExternalFile_testBackwardDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            TestExternalFile.TestExternalFile_checks(testCase, 'local_default', 'cache');
        end
        function TestExternalFile_testMD5Hash(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            v = int64([1;2]);
            packed_cell = mym('serialize {M}', v);
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            testCase.verifyEqual(uuid, '1d751e2e1e74faf84ab485fde8ef72be');
        end
        function  TestExternalFile_test32BitRead(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            value = ['6D596D005302000000010000000100000004000000686974730073696465730074' ...
                '61736B73007374616765004D00000041020000000100000007000000060000000000000' ...
                '0000000000000F8FF000000000000F03F000000000000F03F0000000000000000000000' ...
                '000000F03F0000000000000000000000000000F8FF23000000410200000001000000070' ...
                '0000004000000000000006C006C006C006C00720072006C002300000041020000000100' ...
                '00000700000004000000000000006400640064006400640064006400250000004102000' ...
                '0000100000008000000040000000000000053007400610067006500200031003000'];
            hexstring = value';
            reshapedString = reshape(hexstring,2,length(value)/2);
            hexMtx = reshapedString.';
            decMtx = hex2dec(hexMtx);
            packed = uint8(decMtx);

            data = struct;
            data.stage = 'Stage 10';
            data.tasks = 'ddddddd';
            data.sides = 'llllrrl';
            data.hits = [NaN,1,1,0,1,0,NaN];

            dj.config.use32BitDims(true);
            unpacked = mym('deserialize', packed);
            dj.config.use32BitDims(false);
 
            testCase.verifyEqual(unpacked, data);
        end
    end
end