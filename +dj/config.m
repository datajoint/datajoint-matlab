function res = config(name, value)
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