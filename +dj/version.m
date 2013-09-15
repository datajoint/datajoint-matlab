function varargout = version
% report DataJoint version

v = struct('major',2,'minor',6,'bugfix',0,'released',true);

if nargout
    varargout{1}=v;
else
    comment = {'pre-release','released'};
    fprintf('\nDataJoint version %d.%d.%d (%s)\n\n',...
        v.major, v.minor, v.bugfix, comment{v.released+1})
end
end