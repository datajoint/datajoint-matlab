classdef Computed < dj.internal.AutoPopulate
    % defines a computed table
    properties(Constant)
        tierRegexp = ['(?<computed>' ...
                      dj.Schema.tierPrefixes{strcmp(dj.Schema.allowedTiers, 'computed')} ...
                      dj.Schema.baseRegexp ')']
    end
    methods
        function self = Computed(varargin)
            self@dj.internal.AutoPopulate(varargin{:})
        end
    end
end
