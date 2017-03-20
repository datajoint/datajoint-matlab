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
        obj = dj.ERD(feval(entity{1}));
        r = dj.set('tableErdRadius');
        while min(r)>0
            if r(1)>0
                obj.up
                r(1) = r(1)-1;
            end
            if r(2)>0
                obj.down
                r(2) = r(2)-1;
            end
        end
    else
        obj = dj.ERD(feval([entity{1} '.getSchema']));
    end
    ret = ret + obj;
end
ret.draw
end