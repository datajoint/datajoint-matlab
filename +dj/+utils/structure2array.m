function s = structure2array(s)
% structure2array(s) converts structure s whose fields are Nx1 matrices into
% an Nx1 matrix of structures.
% :: Dimitri Yatsenko :: Created 2010-10-07 :: Modified 2010-10-31

lst = {};
for fname = fieldnames(s)'
    lst{end+1} = fname{1};
    v = s.(fname{1});
    if isempty(v)
        lst{end+1}={};
    else
        if isnumeric(v) || islogical(v)
            lst{end+1} = num2cell(s.(fname{1}));
        else
            lst{end+1} = s.(fname{1});
        end
    end
end

% convert into struct array
s = struct(lst{:});