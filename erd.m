function erd(varargin)
% ERD -- plot the entity relationship diagram of a DataJoint package.
%
% See also dj.Schema/erd, dj.Table.erd

if ~nargin
    disp 'nothing to plot'
    return
end

ret = dj.ERD();
for entity = varargin
    if exist(entity{1}, 'class')
        obj = feval(entity{1});
    else
        obj = feval([entity{1} '.getSchema']);
    end
    ret = ret + dj.ERD(obj);
end
ret.draw
end