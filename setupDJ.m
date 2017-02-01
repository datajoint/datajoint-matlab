function setupDJ
    base = fileparts(mfilename('fullpath'));
    fprintf('Adding DataJoint to the path...\n');
    addpath(base);
    
    mymdir = fullfile(base, 'mym');
    % if mym directory missing, download and install
    if ~isdir(mymdir)
        fprintf('mym missing. Downloading...\n');
        target = fullfile(base, 'mym.zip');
        mymURL = 'https://github.com/datajoint/mym/archive/master.zip';
        target = websave(target, mymURL);
        if isunix && ~ismac
            % on Linux Matlab unzip doesn't work properly so use system
            % unzip
            system(['unzip ', target]);
        else
            unzip(target);
        end
        % rename extracted mym-master directory to mym
        movefile(fullfile(base, 'mym-master'), mymdir);
        delete('mym.zip');
    end
    
    % run mymSetup.m
    fprintf('Setting up mym...\n');
    run(fullfile(mymdir, 'mymSetup.m'));
end