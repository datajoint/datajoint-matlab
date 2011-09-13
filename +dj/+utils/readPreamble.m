function str = readPreamble(filename)
% reads the initial comment block %{ ... %}

f = fopen(filename, 'rt');
if f==-1
    f = fopen([filename, '.m'],'rt');
end
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
