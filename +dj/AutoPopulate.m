% dj.AutoPopulate is deprecated and will be removed in future versions

classdef AutoPopulate < dj.internal.AutoPopulate
    
    methods
        function self = AutoPopulate
            warning('DataJoint:deprecate', ...
                'dj.AutoPopulate is deprecated and will be removed in future versions')
        end
    end
end