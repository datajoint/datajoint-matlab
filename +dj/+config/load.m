function load(fname)
    % LOAD(fname)
    %   Description:
    %     Updates the setting from config file in JSON format.
    %   Inputs:
    %     fname[optional, default=dj.internal.Settings.LOCALFILE]: (string) Config file path.
    %   Examples:
    %     dj.config.load('/path/to/dj_local_conf.json')
    %     dj.config.load
    switch nargin
        case 0
            dj.internal.Settings.load();
        case 1
            dj.internal.Settings.load(fname);
        otherwise
        error('Exceeded 1 input limit.');
    end
end