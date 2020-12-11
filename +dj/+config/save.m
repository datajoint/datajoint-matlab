function save(fname)
    % SAVE(fname)
    %   Description:
    %     Saves the settings in JSON format to the given file path.
    %   Inputs:
    %     fname[required]: (string) Config file path.
    %   Examples:
    %     dj.config.save('/path/to/dj_local_conf.json')
    switch nargin
        case 1
            dj.internal.Settings.save(fname);
        otherwise
        error('Requires 1 input.');
    end
end