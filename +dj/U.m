classdef U
properties (SetAccess=private, Hidden)
    primaryKey
end

methods
    function self = U(varargin)
        % UNIVERSAL SET - a set representing all possible values of the
        % supplied attributes
        % Can be queried in combination with other relations to alter their
        % primary key structure.
        
        self.primaryKey = varargin;
        % self.init('U', {});  % general relvar node
    end

    function ret = and(self, arg)
        ret = self.restrict(arg);
    end

    function ret = restrict(self, arg)
        % RESTRICT - relational restriction
        % dj.U(varargin) & A returns the unique combinations of the keys in
        % varargin that appear in A.
        
        % for dj.U(), only support restricting by a relvar
        assert(isa(arg, 'dj.internal.GeneralRelvar'),...
            'restriction requires a relvar as operand');
        
%         self = init(dj.internal.GeneralRelvar, 'U', {self, arg, 0});
        ret = init(dj.internal.GeneralRelvar, 'U', {arg, self, 0});
    end

    function ret = mtimes(self, arg)
        % MTIMES - relational natural join.
        % dj.U(varargin) * A promotes the keys in varargin to the primary 
        % key of A and returns the resulting relation.
        
        assert(isa(arg, 'dj.internal.GeneralRelvar'), ...
            'mtimes requires another relvar as operand')
        ret = init(dj.internal.GeneralRelvar, 'U', {arg, self, 1});
    end

    function ret = aggr(self, other, varargin)
        % AGGR -- relational aggregation operator.
        % dj.U(varargin).aggr(A,...) Allows grouping by arbitrary
        % combinations of the keys in A.
        
        assert(iscellstr(varargin), ...
            'proj() requires a list of strings as attribute args')
        ret = init(dj.internal.GeneralRelvar, 'aggregate', ...
            [{self & other, self * other}, varargin]);
        %Note: join is required here to make projection semantics work. 
    end
end

end