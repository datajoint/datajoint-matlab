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
        websave(target, mymURL);
        unzip(target);
        % rename extracted mym-master directory to mym
        movefile(fullfile(base, 'mym-master'), mymdir);
        delete('mym.zip');
    end
    
    % run mymSetup.m
    fprintf('Setting up mym...\n');
    run(fullfile(mymdir, 'mymSetup.m'));
end