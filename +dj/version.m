function varargout = version
% report DataJoint version

v = sprintf('DataJoint version 2.5.1');
if ~nargout
    fprintf('\n%s\n\n',v)
else
    varargout{1}=v;
end
end