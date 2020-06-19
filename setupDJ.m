function setupDJ(skipPathAddition, force)

    if nargin < 2
        force = false;
    end

    persistent INVOKED;
    
    if ~isempty(INVOKED) && ~force
        return
    end

    if verLessThan('matlab', '8.6')
        error 'MATLAB version 8.6 (R2015b) or greater is required'
    end

    base = fileparts(mfilename('fullpath'));

    if nargin < 1
        skipPathAddition = false;
    end
    
    if ~skipPathAddition
        fprintf('Adding DataJoint to the path...\n')
        addpath(base)
    end

    mymdir = fullfile(base, 'mym');
    % if mym directory missing, download and install
    if ~isdir(mymdir)
        fprintf('mym missing. Downloading...\n')
        target = fullfile(base, 'mym.zip');
        mymURL = 'https://github.com/datajoint/mym/archive/master.zip';
        target = websave(target, mymURL);
        if isunix && ~ismac
            % on Linux Matlab unzip doesn't work properly so use system unzip
            system(sprintf('unzip -o %s -d %s', target, base))
        else
            unzip(target, base)
        end
        % rename extracted mym-master directory to mym
        movefile(fullfile(base, 'mym-master'), mymdir)
        delete(target)
    end
    
    % run mymSetup.m
    fprintf('Setting up mym...\n')
    run(fullfile(mymdir, 'mymSetup.m'))

    try
        mymVersion = mym('version');
        assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6)
    catch
        error 'Outdated version of mYm.  Please upgrade to version 2.6 or later'
    end

    INVOKED = 1;
end
