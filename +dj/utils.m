classdef(Sealed) utils
    
    properties(Constant)
        % Table naming convention
        %   lookup:   tableName starts with a '#'
        %   manual:   tableName starts with a letter
        %   imported: tableName with a '_'
        %   computed: tableName with '__'
        allowedTiers = {'lookup' 'manual' 'imported' 'computed'}
        tierPrefixes = {'#', '', '_', '__'}
        macros = struct(...
            'JobFields', {{
            'table_name: varchar(255)  # schema.table name for which the job is reserved'
            '---'
            'job_status: enum("reserved","completed","error","ignore") # if tuple is missing, the job is available'
            'error_message="": varchar(1023) # error message returned if failed'
            'error_stack=null: blob  # error stack if failed'
            'job_timestamp=CURRENT_TIMESTAMP: timestamp # automatic timestamp'
            }})
    end
    
    
    methods(Static)
        function str = readPercentBraceComment(filename)
            % reads the initial comment block %{ ... %}
            
            f = fopen(filename, 'rt');
            assert(f~=-1, 'Could not open %s', filename)
            str = '';
            
            % skip all lines that do not begin with a %{
            l = fgetl(f);
            while ischar(l) && ~strcmp(strtrim(l),'%{')
                l = fgetl(f);
            end
            
            if ischar(l)
                while true
                    l = fgetl(f);
                    assert(ischar(l), 'invalid verbatim string');
                    if strcmp(strtrim(l),'%}')
                        break;
                    end
                    str = sprintf('%s%s\n', str, l);
                end
            end
            
            fclose(f);
        end
        
        
        function ret = str2cell(str, delims)
            % converts string into cell array of strings
            
            if nargin<=2
                delims = char([10,13]); % new line characters
            end
            str = [delims(1) str delims(1)];
            pos = find(ismember(str,delims));
            ret = arrayfun(@(i) str(pos(i-1):pos(i)), ...
                2:length(pos),'UniformOutput', false);
            ret = ret(~cellfun(@isempty, ret));
            ret = ret(:);  % convert to column
        end    
        
        
        function str = camelCase(str, reverse)
            % converts underscore_compound_words to camelCase (default) and back when
            % reverse == true
            %
            % Not always inversible
            %
            % str must be either mixed case or contain underscores but not both
            %
            % Examples:
            %   camelCase('one')            -->  'One'
            %   camelCase('one_two_three')  -->  'OneTwoThree'
            %   camelCase('#$one_two,three') --> 'OneTwoThree'
            %   camelCase('One_Two_Three')  --> !error! upper case only mixes with alphanumericals
            %   camelCase('5_two_three')    --> !error! cannot start with a digit
            %
            % Reverse:
            %   camelCase('oneTwoThree', true)    --> 'one_two_three'
            %   camelCase('OneTwoThree', true)    --> 'one_two_three'
            %   camelCase('one two three', true)  --> !error! white space is not allowed
            %   camelCase('ABC', true)            --> 'a_b_c'
            
            reverse = nargin>=2 && reverse;
            assert(ischar(str) && ~isempty(str), 'invalid input')
            assert(isempty(regexp(str, '\s+', 'once')), 'white space is not allowed')
            assert(~ismember(str(1), '0':'9'), 'string cannot begin with a digit')
            
            if reverse
                % from camelCase
                assert(~isempty(regexp(str, '^[a-zA-Z0-9]*$', 'once')), ...
                    'camelCase string can only contain alphanumeric characters');
                str = regexprep(str, '([A-Z])', '_${lower($1)}');
                str = str(1+(str(1)=='_'):end);  % remove leading underscore
            else
                % to camelCase
                assert(isempty(regexp(str, '[A-Z]', 'once')), ...
                    'underscore_compound_words must not contain uppercase characters');
                str = regexprep(str, '(^|[_\W]+)([a-zA-Z])', '${upper($2)}');
            end
        end
        
        
        function s = structure2array(s)
            % structure2array(s) converts structure s whose fields are Nx1 matrices into
            % an Nx1 matrix of structures.
            % :: Dimitri Yatsenko :: Created 2010-10-07 :: Modified 2010-10-31
            
            lst = {};
            for fname = fieldnames(s)'
                lst{end+1} = fname{1};  %#ok<AGROW>
                v = s.(fname{1});
                if isempty(v)
                    lst{end+1}={};   %#ok<AGROW>
                else
                    if isnumeric(v) || islogical(v)
                        lst{end+1} = num2cell(s.(fname{1}));  %#ok<AGROW>
                    else
                        lst{end+1} = s.(fname{1});  %#ok<AGROW>
                    end
                end
            end
            
            % convert into struct array
            s = struct(lst{:});
        end
        
        
        function ret = structJoin(s1, s2)
            % the relational join of structure arrays s1 and s2
            
            assert(isstruct(s1) && isstruct(s2) && size(s1,2)==1 && size(s2,2)==1);
            ret = struct([]);
            commonFields = intersect(fieldnames(s1),fieldnames(s2));
            s2only = setdiff(fieldnames(s2),fieldnames(s1));
            for p2 = s2'
                for p1 = s1'
                    if isequal(...
                            dj.utils.structPro(p1,commonFields), ...
                            dj.utils.structPro(p2,commonFields))
                        for f = s2only'
                            p1.(f{1}) = p2.(f{1});
                        end
                        ret = [ret; p1];   %#ok<AGROW>
                    end
                end
            end
            
        end
        
        
        function s = structPro(s,fields)
            % the relational projection of structure array onto fields
            % Duplicates are not removed.
            for ff=fieldnames(s)'
                if ~ismember(ff{1}, fields)
                    s = rmfield(s, ff{1});
                end
            end
        end
        
        
        function sorted = structSort(s, fieldNames)
            % sort structure array s alphanumerically in order of fieldNames
            % Example:
            % >> s = struct('a', {1,1,2}, 'b', {'one' 'two' 'two'}, 'c', {1 2 1})'
            % >> s = structSort(s, 'c');
            % >> s = structSort(s, {'b','a'})
            
            assert(isstruct(s) && ndims(s)==2 && size(s,2)==1, ...
                'first input must be a column array of structures.')
            if ischar(fieldNames)
                fieldNames = {fieldNames};
            end
            assert(iscellstr(fieldNames) && all(isfield(s, fieldNames)), ...
                'second input must be an array of fieldnames');
            f = fieldnames(s);
            c = struct2cell(s)';
            [~,i] = ismember(fieldNames,f);
            [~,i] = sortrows(c(:,i));
            sorted = s(i);
        end
    end
end