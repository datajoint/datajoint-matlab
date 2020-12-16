classdef Imported < dj.internal.AutoPopulate
    % defines an imported table
    properties(Constant)
        tierRegexp = sprintf('(?<imported>%s%s)', ...
            dj.Schema.tierPrefixes{strcmp(dj.Schema.allowedTiers, 'imported')}, ...
            dj.Schema.baseRegexp)
    end
    methods
        function self = Imported(varargin)
            self@dj.internal.AutoPopulate(varargin{:})
        end
    end
end
