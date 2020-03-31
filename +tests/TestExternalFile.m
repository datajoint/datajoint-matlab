classdef TestExternalFile < tests.Prep
    % TestExternalFile tests scenarios related to external file store.
    methods (Static)
        function TestExternalFile_checks(test_instance, store, cache)
            % load config
            pkg = what('tests');
            ext_root = strrep(test_instance.external_file_store_root, '\', '/');
            dj.config.load([strrep(pkg.path, '\', '/') '/test_schemas/store_config.json']);
            dj.config(['stores.' store '.location'], strrep(dj.config(...
                ['stores.' store '.location']), '{{external_file_store_root}}', ...
                ext_root));
            dj.config('stores.main', dj.config(['stores.' store]));
            dj.config(cache, [ext_root '/cache']);
            % create location/cache directories
            mkdir(dj.config(cache));
            mkdir(dj.config('stores.main.location'));
            % create schema
            package = 'External';
            dj.createSchema(package,[test_instance.test_root '/test_schemas'], ...
                [test_instance.PREFIX '_external']);
            schema = External.getSchema;
            % test value
            rng(5);
            test_val1 = floor(rand(1,3)*100);
            % insert and fetch
            insert(External.Dimension, struct( ...
                'dimension_id', 4, ...
                'dimension', test_val1 ...
            ));
            q = External.Dimension & 'dimension_id=4';
            res = q.fetch('dimension');
            value_check = res(1).dimension;
            test_instance.verifyEqual(value_check,  test_val1);
            % check subfolding
            packed_cell = mym('serialize {M}', test_val1);
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            uuid_path = schema.external.table('main').make_uuid_path(uuid, '');
            subfold_path = strrep(uuid_path, dj.config('stores.main.location'), '');
            subfold_path = strrep(subfold_path, ['/' schema.dbname '/'], '');
            subfold_path = strrep(subfold_path, ['/' uuid], '');
            test_instance.verifyEqual(cellfun(@(x) length(x), split(subfold_path, '/')), ...
                schema.external.table('main').spec.type_config.subfolding);
            % delete value to rely on cache
            if ispc
                [status,cmdout] = system(['rmdir /Q /s "' ...
                    test_instance.external_file_store_root '\base"']);
            else
                [status,cmdout] = system(['rm -R ' ...
                    test_instance.external_file_store_root '/base']);
            end
            res = q.fetch('dimension');
            value_check = res(1).dimension;
            test_instance.verifyEqual(value_check,  test_val1);
            % populate
            populate(External.Image);
            q = External.Image & 'dimension_id=4';
            res = q.fetch('img');
            value_check = res(1).img;
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
            test_instance.verifyEqual(lastwarn,  ['File ''' ...
                dj.config('stores.main.location') '/' schema.dbname '/' subfold_path '/' ...
                uuid ''' not found.']);
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
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'new_local', 'blobCache');
        end
        function TestExternalFile_testLocalDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'new_local_default', ...
                'blobCache');
        end
        function TestExternalFile_testBackward(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'local', 'cache');
        end
        function TestExternalFile_testBackwardDefault(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            tests.TestExternalFile.TestExternalFile_checks(testCase, 'local_default', 'cache');
        end
        function TestExternalFile_testMD5Hash(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            v = int64([1;2]);
            packed_cell = mym('serialize {M}', v);
            uuid = dj.lib.DataHash(packed_cell{1}, 'bin', 'hex', 'MD5');
            testCase.verifyEqual(uuid, '1d751e2e1e74faf84ab485fde8ef72be');
        end
    end
end