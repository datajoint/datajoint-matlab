function load(fname)
    switch nargin
        case 0
            dj.internal.Settings.load();
        case 1
            dj.internal.Settings.load(fname);
        otherwise
        error('Exceeded 1 input limit.');
    end
end