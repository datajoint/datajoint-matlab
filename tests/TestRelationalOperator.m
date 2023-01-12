classdef TestRelationalOperator < Prep
    methods (TestClassSetup)
        function init(testCase)
            init@Prep(testCase);
            package = 'University';
            dj.createSchema(package,[testCase.test_root '/test_schemas'], ...
                [testCase.PREFIX '_university']);
            University.Student().insert(struct(...
                'student_id', {1,2,3,4},...
                'first_name', {'John','Paul','George','Ringo'},...
                'last_name',{'Lennon','McCartney','Harrison','Starr'},...
                'enrolled',{'1960-01-01','1960-01-01','1960-01-01','1960-01-01'}...
                ));
                
            University.A().insert({1, 'test', '1960-01-01 00:00:00','1960-01-01', 1.234, struct()});
        end
            
    end
    methods (Test)
        function TestRelationalOperator_testUnion(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            
            
            % Unions may only share primary, but not secondary, keys
            testCase.verifyError(@() count(University.Student() | University.Student()), 'DataJoint:invalidUnion');
            % The primary key of each relation must be the same
            testCase.verifyError(@() count(University.A() | University.Student()), 'DataJoint:invalidUnion');
            
            % A basic union
            testCase.verifyEqual(count(...
                proj(University.Student() & 'student_id<2') | proj(University.Student() & 'student_id>3')),...
                2);

            % Unions with overlapping primary keys are merged
            testCase.verifyEqual(count(...
                proj(University.Student() & 'student_id<3') | proj(University.Student() & 'student_id>1 AND student_id<4')),...
                3);
            
            % Unions with disjoint secondary keys are also merged and filled with NULL
            a = University.Student & 'student_id<4';
            b = proj(University.Student() & 'student_id>1','"test_val"->test_col');
            c = fetch(a | b, '*');
            testCase.verifyEqual(length(c), 4);
            testCase.verifyEqual(nnz(cellfun(@isempty,{c(:).first_name})), 1);
            testCase.verifyEqual(nnz(cellfun(@isempty,{c(:).test_col})), 1);
            testCase.verifyEqual(nnz(cellfun(@isempty,{c(:).first_name}) & cellfun(@isempty,{c(:).test_col})), 0);            

        end

        function TestRelationalOperator_testUniversalSet(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
        
            % dj.U() & rel has no attributes
            a = dj.U() & University.Student();
            testCase.verifyError(@() a.header.sql, 'DataJoint:missingAttributes');
            
            % dj.U(c) * rel is invalid if c is not an attribute of rel
            testCase.verifyError(@() count(dj.U('bad_attribute') * University.Student()), 'DataJoint:missingAttributes');
            
            % rel = dj.U(c) * rel promotes c to a primary key of rel
            a = dj.U('first_name') * University.Student();
            testCase.verifyTrue(ismember('first_name', a.primaryKey));
            testCase.verifyEqual(length(a.primaryKey), 2);
            
            % dj.U(c) & rel returns the unique combinations of c in rel
            a = dj.U('enrolled') & University.Student();
            testCase.verifyEqual(count(a), 1);
            testCase.verifyEqual(length(a.header.attributes), 1);
            a = dj.U('last_name','enrolled') & University.Student();
            testCase.verifyEqual(count(a), 4);
            testCase.verifyEqual(length(a.header.attributes), 2);
            
            % dj.U(c).aggr(rel, ...) aggregates into the groupings in c that exist in rel
            a = dj.U('last_name').aggr(University.Student(), 'length(min(first_name))->n_chars');
            testCase.verifyEqual(length(a.primaryKey),1);
            testCase.verifyTrue(strcmp(a.primaryKey{1}, 'last_name'));
            testCase.verifyEqual(count(a), 4);
            testCase.verifyEqual(length(a.nonKeyFields), 1);
            testCase.verifyTrue(strcmp(a.nonKeyFields{1}, 'n_chars'));
            
            % dj.U(c) supports projection semantics on c
            a = dj.U('left(first_name,1)->first_initial') & University.Student();
            testCase.verifyEqual(length(a.primaryKey), 1);
            testCase.verifyTrue(strcmp(a.primaryKey{1}, 'first_initial'));
            testCase.verifyEqual(count(a), 4);
            

        end
    end
end