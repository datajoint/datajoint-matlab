function erd(varargin)
% ERD -- plot the entity relationship diagram of a DataJoint package.
%
% See also dj.Schema/erd, dj.Table.erd

switch nargin
    case 0
        disp 'nothing to plot'
    case 1
        entity = varargin{1};
        if any(entity=='.')
            erd(dj.Relvar(entity))
        else
            erd(feval([entity '.getSchema']))
        end
    otherwise
        list = {};
        conn = [];
        for entity = varargin
            if any(entity{1}=='.')
                table = feval(entity{1});
                conn = table.schema.conn;
                list = union(list,{table.fullTableName});
            else
                schema = feval([entity{1} '.getSchema']);
                conn = schema.conn;
                list = union(list, ...
                    cellfun(@(s) sprintf('`%s`.`%s`', schema.dbname, s), ...
                    schema.tableNames.values, 'uni', false));
            end
        end
        conn.erd(list(:)')
end