classdef Manual < dj.internal.UserRelation
% Defines a manual table
    methods
        function self = Manual(varargin)
            self@dj.internal.UserRelation(varargin{:})
        end
    end
end