function setupDJ(skipPathAddition, force)

    if nargin < 2
        force = false;
    end

    persistent INVOKED;
    
    if ~isempty(INVOKED) && ~force
        return
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
    
    INVOKED = 1;
end
