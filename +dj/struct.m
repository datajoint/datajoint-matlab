classdef struct
    % DJ.STRUCT - a collection of common operations on structure arrays.
    
    methods(Static)
        
        function sorted = sort(s, fieldNames)
            % DJ.STRUCT.SORT - structure array s alphanumerically in order of fieldNames
            % Example:
            % >> s = struct('a', {1,1,2}, 'b', {'one' 'two' 'two'}, 'c', {1 2 1})'
            % >> s = structSort(s, 'c');
            % >> s = structSort(s, {'b','a'})
            
            assert(isstruct(s) && ismatrix(s) && size(s,2)==1, ...
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
            assert(isstruct(s1) && isstruct(s2) && size(s1,2)<=1 && size(s2,2)<=1);
            ret = struct([]);
            commonFields = intersect(fieldnames(s1),fieldnames(s2));
            s2only = setdiff(fieldnames(s2),fieldnames(s1));
            for p2 = s2'
                for p1 = s1'
                    if isequal(...
                            dj.struct.proj(p1,commonFields{:}), ...
                            dj.struct.proj(p2,commonFields{:}))
                        for f = s2only'
                            p1.(f{1}) = p2.(f{1});
                        end
                        ret = [ret; p1];   %#ok<AGROW>
                    end
                end
            end
            
        end
        
        function ret = leftOuterJoin(s1, s2, fill)
            % DJ.STRUCT.LEFTOUTERJOIN - Relational left outer join
            % Required arguments:
            %   s1      Struct array of tuples
            %   s2      Struct array of tuples
            %   fill    Value to use for non-matching tuples. Default = []
            % Returns a struct array with all the fields of s1 and s2.
            % Tuples in:
            %  both s1 and s2: returned like a natural join
            %   s1 but not s2 : take the fill value for the s2-only fields
            %   s2 but not s1 : not returned
            % "fill" can be specified as a scalar or as a struct containing
            % the s2-only fields
            assert(isstruct(s1) && isstruct(s2));
            f1 = fieldnames(s1);
            f2 = fieldnames(s2);
            fcommon = intersect(f1,f2);
            fs1only = setdiff(f1,f2);
            fs2only = setdiff(f2,f1);
            % Check that we have something to do
            if isempty(s1)
                args = union(f1,f2)';
                args = [args ; repmat({{}}, 1, length(args))];
                ret = struct(args{:});
                return
            end 
            if isempty(fs2only)
                ret = s1;
                return
            end
            assert(iscolumn(s1) && (iscolumn(s2) || isempty(s2)));
            % Check the fill values
            if nargin < 3
                fill = [];
            end
            if isstruct(fill)
                % Ensure the fieldnames match up
                assert(isempty(setxor(fs2only, fieldnames(fill))));
            else
                % Turn fill into a struct array with the s2-only fieldnames
                args = [fs2only' ; repmat({fill},1,length(fs2only)) ];
                fill = struct(args{:});
            end
            % Do the joining
            ret = struct([]);
            s2common = dj.struct.proj(s2, fcommon{:});
            for p1 = s1'
                % Find the matches in s2
                p1common = dj.struct.proj(p1, fcommon{:});
                isMatch = arrayfun(@(x) isequal(x,p1common), s2common);
                if any(isMatch)
                    % Copy the matching s2 tuples and add the p1 fields
                    add = s2(isMatch);
                    for fc=1:numel(fs1only)
                        [add.(fs1only{fc})] = deal(p1.(fs1only{fc}));
                    end
                else
                    % Copy p1 and add the fill values
                    add = p1;
                    for f = fs2only'
                        add.(f{1}) = fill.(f{1});
                    end
                end
                % Add the new tuples to the output
                ret = [ret; add]; %#ok<AGROW>
                % Go on to the next tuple in s1
            end
            % Done!
        end


        function s = pro(s, varargin)
            % alias for dj.struct.proj for backward compatibility
            s = dj.struct.proj(s, varargin{:});            
        end
        
        function s = proj(s,varargin)
            % DJ.STRUCT.PROJ - the relational projection operator
            % of structure array onto the specified fields.
            % The result may contain duplicate tuples.
            %
            % SYNTAX:
            %    s = dj.struct.proj(s, 'field1', 'field2')
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
            assert(isscalar(s) && isstruct(s), 'the input must be a scalar structure')
            
            fnames = fieldnames(s)';
            lst = cell(1,length(fnames)*2);
            for i = 1:length(fnames)
                lst{i*2-1} = fnames{i};
                v = s.(fnames{i});
                if isempty(v)
                    lst{i*2}={};
                else
                    if isnumeric(v) || islogical(v) ||  isstring(v)
                        lst{i*2} = num2cell(s.(fnames{i}));
                    else
                        lst{i*2} = s.(fnames{i});
                    end
                end
            end
            s = struct(lst{:});
        end
        
        
        function s = rename(s, varargin)
            % dj.struct.rename - rename fields
            % SYNTAX:
            %    s = dj.struct.rename(s,oldName1,newName1,...,oldNameN,newNameN)
            for i=1:2:length(varargin)
                [s.(varargin{i+1})] = deal(s.(varargin{i}));
                s = rmfield(s,varargin{i});
            end
        end
        
        
        function [tab,varargout] = tabulate(s,valueField,varargin)
            % dj.struct.tablulate - convert structure array into a multidimensional array
            %
            % [tab,v1,..,vn] = dj.struct.tabulate(struc, valueField, idxField1, ..., idxFieldN)
            % creates the (n+1)-dimensional array tab from the structure array
            % where each dimension is indexed by the value of the fields
            % idxField1,...,idxFieldN and stores the values of valueField. If multiple
            % values of valueField are present for some combinations of
            % indexes, they are accumulated along the last dimension
            %
            % v1,...,vn  will contain arrays of unique values for the index
            % fields corresponding to each dimension.
            
            indexFields = varargin;
            assert(isstruct(s) && ~isempty(s))
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
            tab = cell(sz);
            m = zeros(sz);
            for i=1:numel(s)
                ixx = cellfun(@(ix) ix(i), ix, 'uni', false);
                j = m(ixx{:})+1;
                m(ixx{:})=j;
                if j>sz(end)
                    % extend the additional dimension
                    tab = cat(length(sz), tab, cell([sz(1:end-1) 1]));
                    sz(end)=sz(end)+1;
                end
                value = s(i).(valueField);
                tab{ixx{:},j}=value;
            end
            if all(arrayfun(@(s) isnumeric(s.(valueField)) && isscalar(s.(valueField)), s))
                tab(cellfun(@isempty,tab))={nan};  % replace empties with nans
                tab = cellfun(@double, tab);  % convert to double; cell2mat fails when cells of different numeric types
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
