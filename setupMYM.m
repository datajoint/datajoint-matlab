function mymVersion = setupMYM(version, force)

    default_version = 'master'; % else git tag string e.g. '2.7.2'

    if nargin < 1
        version = default_version;
    end
    if nargin < 2
        force = false;
    end

    persistent INSTALLED_VERSION;
    
    if ~isempty(INSTALLED_VERSION) && ~force
        mymVersion = INSTALLED_VERSION;
        return;
    end

    base = fileparts(mfilename('fullpath'));

    mymdir = fullfile(base, 'mym');
    
    if isdir(mymdir)
        if force
            fprintf('force install.. removing %s\n', mymdir);
            rmdir(mymdir, 's');
        elseif(~strcmp(version, default_version))
            warning('DataJoint:System:setupMyMwarning', ...
                    ['Warning: mym directory exists. not re-installing.\n', ...
                     '  to override, pass force=true\n']);
        end
    end

    if ~isdir(mymdir) %% mym directory missing, download and install
        fprintf('Installing %s...\n', version);
        target = fullfile(base, 'mym.zip');

        mymURL = 'https://github.com/datajoint/mym/archive/';

        if strcmp(version, 'master')
            mymURL = strcat(mymURL, version, '.zip');
        else
            mymURL = strcat(mymURL, 'v', version, '.zip');
        end

        fprintf('downloading %s to %s\n', mymURL, target);
        target = websave(target, mymURL);

        extdir = fullfile(base, sprintf('mym-%s', version));
        fprintf('extracting %s into %s\n', target, extdir);

        if isunix && ~ismac
            % on Linux Matlab unzip doesn't work properly so use system unzip
            system(sprintf('unzip -o %s -d %s', target, base));
        else
            unzip(target, base);
        end

        % rename extracted mym-master directory to mym
        fprintf('renaming %s to %s\n', extdir, mymdir);
        movefile(extdir, mymdir);

        delete(target);
    end

    % run mymSetup.m
    fprintf('Setting up mym...\n');
    run(fullfile(mymdir, 'mymSetup.m'));

    mymVersion = version;
    INSTALLED_VERSION = mymVersion;

end 
