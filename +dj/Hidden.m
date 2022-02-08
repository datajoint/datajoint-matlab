classdef Hidden < dj.internal.UserRelation
    properties(Constant)
        tierRegexp = sprintf('(?<hidden>%s%s)', ...
            dj.Schema.tierPrefixes{strcmp(dj.Schema.allowedTiers, 'hidden')}, ...
            dj.Schema.baseRegexp)
    end
    methods
        function self = Hidden(varargin)
            self@dj.internal.UserRelation(varargin{:})
        end
    end
end