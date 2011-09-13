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