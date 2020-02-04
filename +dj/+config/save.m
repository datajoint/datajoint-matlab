function save(fname)
    switch nargin
        case 0
            dj.internal.Settings.save();
        case 1
            dj.internal.Settings.save(fname);
        otherwise
        error('Exceeded 1 input limit.');
    end
end