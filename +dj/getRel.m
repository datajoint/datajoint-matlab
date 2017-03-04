function rel = getRel(name)
% get a relation object from a name

try
    rel = eval(name);
catch
    parts = strsplit(name, '.');
    try
        master = eval(strjoin(parts(1:end-1), '.'));
        rel = master.(parts{end});
    catch
        rel = dj.Relvar(name);
    end
end

assert(isa(rel, 'dj.Relvar'), '%s is not a relation', name)
end