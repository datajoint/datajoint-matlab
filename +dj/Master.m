classdef Master < handle
    % mix-in class for dj.Relvar classes to make them process parts in a
    % master/part relationship.
    
    properties(Access=private)
        parts_ = {}
    end
    
    methods
        function self = Master
            % find all parts and assign their properties part_name_ and master_
            props = properties(self);
            for i=1:length(props)
                name = props{i};
                if ismember(name(1), 'A':'Z') && isa(self.(name), 'dj.Part')
                    assert(~isempty(regexp(name, '^[A-Z][a-z0-9]*$', 'match')), ...
                        'part name must be in CamelCase and capitalized.')
                    self.(name).part_name_ = name;
                    self.(name).master_ = self;
                    self.parts_{end+1} = name;
                end
            end
        end
    end
end