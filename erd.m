function erd(entity)
% ERD -- plot the entity relationship diagram of a DataJoint package.
% 
% See also dj.Schema/erd, dj.Table.erd

if ~any(entity=='.')
     erd(eval([entity '.getSchema']))
else
    erd(eval([entity '.table']))
end