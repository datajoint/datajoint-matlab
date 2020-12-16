classdef Jobs < dj.Relvar
    properties(Constant)
        tierRegexp = sprintf('(?<job>%s%s)', ...
            dj.Schema.tierPrefixes{strcmp(dj.Schema.allowedTiers, 'job')}, ...
            dj.Schema.baseRegexp)
    end
    methods
        function self = Jobs(varargin)
            self@dj.Relvar(varargin{:})
        end
    end
end
