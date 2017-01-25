classdef Part < dj.Relvar 
    
    properties(Constant)
        tier = 'part'
    end
    
    properties(Abstract)
        master 
    end
end
