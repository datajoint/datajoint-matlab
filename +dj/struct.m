classdef struct
    % DJ.STRUCT - a collection of common operations on structure arrays.
    
    methods(Static)
        
        function sorted = sort(s, fieldNames)
            % DJ.STRUCT.SORT - structure array s alphanumerically in order of fieldNames
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
        
        
        function ret = join(s1, s2)
            % DJ.STRUCT.JOIN - the relational join of structure arrays s1 and s2
            
            assert(isstruct(s1) && isstruct(s2) && size(s1,2)==1 && size(s2,2)==1);
            ret = struct([]);
            commonFields = intersect(fieldnames(s1),fieldnames(s2));
            s2only = setdiff(fieldnames(s2),fieldnames(s1));
            for p2 = s2'
                for p1 = s1'
                    if isequal(...
                            dj.struct.pro(p1,commonFields), ...
                            dj.struct.pro(p2,commonFields))
                        for f = s2only'
                            p1.(f{1}) = p2.(f{1});
                        end
                        ret = [ret; p1];   %#ok<AGROW>
                    end
                end
            end
            
        end
        
        
        function s = pro(s,fields)
            % DJ.STRUCT.PRO - the relational projection operator
            % of structure array onto fields
            % Duplicates are not removed.
            for ff=fields(:)'
                if isfield(s,ff{1})
                    s = rmfield(s, ff{1});
                end
            end
        end
        
        
        function s = fromFields(s)
            % DJ.STRUCT.FROMFIELDS - construct a structure array from a
            % scalar structure whose fields contain same-sized arrays of values.
            
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
    end
end