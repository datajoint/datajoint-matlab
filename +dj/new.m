function new(className)
% DJ.NEW - interactively create a new DataJoint table/class
%
% INPUT:
%   className in the format 'package.ClassName'

if nargin<1
    className = input('Enter <package>.<ClassName>: ','s');
end

p = find(className == '.', 1, 'last');
if isempty(p)
    throwAsCaller(MException('DataJoint:makeClass', 'dj.new requires package.ClassName"'))
end

schemaFunction = [className(1:p-1) '.getSchema'];
if isempty(which(schemaFunction))
    fprintf('Package %s is missing. Calling dj.createSchema...\n', className(1:p-1))
    % this wouldn't work well if nested package is given
    dj.createSchema(className(1:p-1))
    if isempty(which(schemaFunction))
        throwAsCaller(MException('DataJoint:makeClass', 'Cannot find %s', schemaFunction))
    end
end

makeClass(eval(schemaFunction), className(p+1:end))