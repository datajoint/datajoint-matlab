classdef Shared < dj.internal.UserRelation
% A dummy implementation of a shared table... Does not enforced the shared key rules

    properties(Constant)
        tierRegexp = sprintf('(?<manual>%s%s)', ...
            dj.Schema.tierPrefixes{strcmp(dj.Schema.allowedTiers, 'manual')}, ...
            dj.Schema.baseRegexp)
    end
    methods
        function self = Shared(varargin)
            self@dj.internal.UserRelation(varargin{:})
        end
    end
end