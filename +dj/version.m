function varargout = version
% report DataJoint version

v = struct('major',3,'minor',3,'bugfix',1);

if nargout
    varargout{1}=v;
else
    fprintf('\nDataJoint version %d.%d.%d\n\n', v.major, v.minor, v.bugfix)
end
