classdef Lookup < dj.internal.UserRelation
    % defines a lookup table
    
    methods
        function self = Lookup()
            if isprop(self, 'contents')
                if length(self.contents) > count(self)
                    self.inserti(self.contents)
                end
            end
        end
    end
end
