% dj.AutoPopulate is deprecated and will be removed in future versions

classdef AutoPopulate < dj.internal.AutoPopulate
    
    methods
        function self = AutoPopulate
            warning('DataJoint:deprecate', ...
                'dj.AutoPopulate is deprecated and will be removed in future versions.  Replace with dj.Imported and dj.Computed (subclasses of dj.Relvar).')
        end
    end
end