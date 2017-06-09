classdef Table < dj.internal.Table
    
    methods
        function self = Table(varargin)
            warning('DataJoint:deprecate', ...
                'dj.Table has been deprecated and will be removed in a future version')
            self = self@dj.internal.Table(varargin{:});
        end            
    end
    
end