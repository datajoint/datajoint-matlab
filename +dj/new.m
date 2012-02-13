function new(className)
% DJ.NEW - interactively create a new DataJoint table/class
%
% INPUT:
%   className in the format "package.ClassName"

p = find(className == '.', 1, 'last');
assert(~isempty(p), 'dj.new: specify package.ClassName"')

schemaObj = eval([className(1:p-1) '.getSchema']);
schemaObj.makeClass(className(p+1:end))