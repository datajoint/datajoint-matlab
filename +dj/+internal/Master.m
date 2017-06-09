classdef Master < handle
    % mix-in class for dj.Relvar classes to make them process parts in a
    % master/part relationship.
    
    methods
        function list = getParts(self)
            % find classnames that begin with me and are dj.Part
            info = meta.class.fromName(class(self));
            classNames = {info.ContainingPackage.ClassList.Name};
            list = cellfun(@feval, classNames(dj.lib.startsWith(classNames, class(self))), 'uni', false);
            list = list(cellfun(@(x) isa(x, 'dj.Part'), list));
        end
    end
end
