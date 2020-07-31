function setupDJ(skipPathAddition, force)

    if nargin < 2
        force = false;
    end

    persistent INVOKED;
    
    if ~isempty(INVOKED) && ~force
        return
    end

    if verLessThan('matlab', '9.1')
        error('DataJoint:System:UnsupportedMatlabVersion', ...
              'MATLAB version 9.1 (R2016b) or greater is required');
    end

    base = fileparts(mfilename('fullpath'));

    if nargin < 1
        skipPathAddition = false;
    end

    if ~skipPathAddition
        fprintf('Adding DataJoint to the path...\n');
        addpath(base);
    end

    setupMYM('master', force);

    try
        mymVersion = mym('version');
        assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6);
    catch
        error('DataJoint:System:UnsupportedMyMVersion', ...
              'Outdated version of mYm.  Please upgrade to version 2.6 or later');
    end

    INVOKED = 1;
end
