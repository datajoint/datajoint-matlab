classdef R2009CopyableRelvarMixin < handle
    properties(Abstract, SetAccess=private, GetAccess=protected)
        operator
        operands
    end
    
    properties(Abstract, SetAccess=private, GetAccess=public)
        restrictions
    end
    
    methods
        function cp = copy(self)
            if isa(self, 'dj.BaseRelvar')
                cp = init(dj.BaseRelvar, self);
            elseif isa(self, dj.GeneralRelvar)
                cp = init(dj.GeneralRelvar, self.operator, self.operands, self.restrictions);
            else
                throwAsCaller(MException('R2009CopyableRelvarMixin only works with dj.Relvars'))
            end
        end
    end
end