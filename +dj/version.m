function varargout = version
% report DataJoint version

v = struct('major',2,'minor',6,'bugfix',6);

if nargout
    varargout{1}=v;
else
    fprintf('\nDataJoint version %d.%d.%d\n\n', v.major, v.minor, v.bugfix)
end