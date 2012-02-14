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
        
        
        function ret = str2cell(str)
            % DJ.UTILS.STR2CELL - convert a multi-line string into a cell array of one-line strings.           
            ret = regexp(str,'\n','split')';
            ret = ret(~cellfun(@isempty, ret));  % remove empty strings
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
        
        
        
        % DEPRECATED FUNCTIONS        
        function s = structure2array(s)
            warning('DataJoint:deprecated',...
                'dj.utils.structure2array will be removed in an upcoming revision. Use dj.struct.fromFields instead')
            s = dj.struct.fromFields(s);
        end
        function ret = structJoin(s1, s2)
            warning('DataJoint:deprecated',...
                'dj.utils.structJoin will be removed in an upcoming revision. Use dj.struct.join instead' )
            ret = dj.struct.join(s1,s2);
        end
        function s = structPro(s,fields)
            warning('DataJoint:deprecated',...
                'dj.utils.structPro will be removed in an upcoming revision. Use dj.struct.pro instead' )
            s = dj.struct.pro(s,fields);
        end
        function sorted = structSort(s, fieldNames)
            warning('DataJoint:deprecated',...
                'dj.utils.structSort will be removed in an upcoming revision. Use dj.struct.sort instead' )
            sorted = dj.struct.sort(s, fieldNames);
        end
    end
end