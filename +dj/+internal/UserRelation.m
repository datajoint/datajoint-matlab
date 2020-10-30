classdef UserRelation < dj.Relvar & dj.internal.Master
    methods
        function self = UserRelation(varargin)
            self@dj.Relvar(varargin{:})
        end
    end
end
