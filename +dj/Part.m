classdef Part < dj.Relvar
    
    properties(Abstract, SetAccess=protected)
        master
    end
    
    methods
        function self = Part
            assert(isa(self.master, 'dj.internal.Master'),...
                'The property master should be a UserRelation')
            assert(~isempty(regexp(class(self), sprintf('^%s[A-Z]', class(self.master)), 'once')), ...
                'The part class %s must be prefixed with its master %s', ...
                class(self), class(self.master))
        end
    end
    
end
