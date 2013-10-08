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
                            dj.struct.pro(p1,commonFields{:}), ...
                            dj.struct.pro(p2,commonFields{:}))
                        for f = s2only'
                            p1.(f{1}) = p2.(f{1});
                        end
                        ret = [ret; p1];   %#ok<AGROW>
                    end
                end
            end
            
        end
        
        
        function s = pro(s,varargin)
            % DJ.STRUCT.PRO - the relational projection operator
            % of structure array onto the specified fields.
            % The result may contain duplicate tuples.
            %
            % SYNTAX:
            %    s = dj.struct.pro(s, 'field1', 'field2')
            %    This removes all fields from s except field1 and field2
            
            for ff=fieldnames(s)'
                if ~ismember(ff{1}, varargin)
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
        
        
        function [tab,varargout] = tabulate(s,numField,varargin)
            % dj.struct.tablulate - convert structure array into a multidimensional array
            %
            % [tab,v1,..,vn] = dj.struct.tabulate(struc, numField, dim1, ..., dimn)
            % creates the (n+1)-dimensional array tab from the structure array
            % where each dimension is indexed by the value of the fields
            % dim1,...,dimn and stores the values of numField. If multiple
            % values of numField are present for some combinations of
            % indexes, an additional dimension is added to store the
            % repeats.
            %
            % v1,...,vn  will contain arrays of unique values for the index
            % fields corresponding to each dimension.
            
            indexFields = varargin;
            assert(isstruct(s) && ~isempty(s))
            assert(isnumeric(s(1).(numField)))
            n = length(indexFields);
            assert(n>0)
            ix = cell(n,1);
            v  = cell(n,1);
            
            for i=1:n
                if isnumeric(s(1).(indexFields{i}))
                    [v{i},~,ix{i}] = unique([s.(indexFields{i})]);
                else
                    [v{i},~,ix{i}] = unique({s.(indexFields{i})});
                end
            end
            sz = [cellfun(@length,v)' 1];
            tab = nan(sz);
            m = zeros(sz);
            for i=1:length(s)
                ixx = cellfun(@(ix) ix(i), ix, 'uni', false);
                j = m(ixx{:})+1;
                m(ixx{:})=j;
                if j>sz(end)
                    % extend the additional dimension
                    tab = cat(length(sz), tab, nan(sz(1:end-1)));
                    sz(end)=sz(end)+1;
                end
                value = s(i).(numField);
                assert(isnumeric(value) && isscalar(value), ...
                    'tabulated field must be scalar numeric')
                tab(ixx{:},j)=value;
            end
            varargout = v';
        end
        
        
        function str = makeCode(s)
            % str = dj.struct.makeCode(s)
            % make matlab code to reproduce the structure array s
            
            str = 'cell2struct({...';
            for i=1:length(s)
                str = sprintf('%s\n   %s', str, cellArrayString(struct2cell(s(i))));
            end
            f = fieldnames(s);
            str = sprintf('%s\n},{...\n%s\n},2);',str,sprintf(' ''%s''',f{:}));
        end
    end
end


function str = cellArrayString(array)
% convert a cell array
assert(iscell(array) && size(array,2)==1,'invalid array type or size')
str = '';
for i=1:length(array)
    v = array{i};
    switch true
        case isnumeric(v) && isscalar(v)
            if ismember(class(v),{'double','single'})
                s = sprintf('%1.16g', v);
            else
                s = sprintf('%d', v);
            end
        case ischar(v)
            s = sprintf('''%s''', v);
        otherwise
            error 'cannot convert field value into string'
    end
    str = sprintf('%s %s', str, s);
end
end
