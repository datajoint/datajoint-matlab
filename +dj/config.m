function res = config(name, value)
    % CONFIG(name, value)
    %   Description:
    %     Manage DataJoint configuration.
    %   Inputs:
    %     name[optional]: (string) Dot-based address to desired setting.
    %     value[optional]: (string) New value to be set.
    %   Examples:
    %     dj.config
    %     dj.config('safemode')
    %     dj.config('safemode', true)
    %     previous_value = dj.config('safemode', false)
    %     dj.config('stores.external_raw', struct(...
    %         'datajoint_type', 'blob', ...
    %         'protocol', 'file', ...
    %         'location', '/net/djblobs/myschema' ...
    %     ))
    %     dj.config('stores.external', struct(...
    %         'datajoint_type', 'blob', ...
    %         'protocol', 's3', ...
    %         'endpoint', 's3.amazonaws.com:9000', ...
    %         'bucket', 'testbucket', ...
    %         'location', 'datajoint-projects/lab1', ...
    %         'access_key', '1234567', ...
    %         'secret_key', 'foaf1234'...
    %     ))
    %     dj.config('blobCache', '/net/djcache')
    switch nargin
        case 0
            out = dj.internal.Settings;
            res = out.result;
        case 1
            out = dj.internal.Settings(name);
            res = out.result;
        case 2
            switch nargout
                case 0
                    dj.internal.Settings(name, value);
                case 1
                    out = dj.internal.Settings(name, value);
                    res = out.result;
                otherwise
                error('Exceeded 1 output limit.')
            end
        otherwise
        error('Exceeded 2 input limit.')
    end
end