function varargout = version
% report DataJoint version

v = struct('major',3,'minor',2,'bugfix',2);

if nargout
    varargout{1}=v;
else
    fprintf('\nDataJoint version %d.%d.%d\n\n', v.major, v.minor, v.bugfix)
end
