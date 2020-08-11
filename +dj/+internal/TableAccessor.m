% dj.internal.TableAccessor allows access to tables without requiring the
% creation of classes.
%
% Initialization:
%    v = dj.internal.TableAccessor(schema);
% 
% MATLAB does not allow the creation of classes without creating
% corresponding classes.
%
% TableAccessor provides a way to access all tables in a schema without
% having to first create the classes. A TableAccessor object is created as
% a property of a schema during the schema's creation. This property is
% named schema.v for 'virtual class generator.' The TableAccessor v itself
% has properties that refer to the tables of the schema.
%
% For example, one can access the Session table using schema.v.Session with
% no need for any Session class to exist in Matlab. Tab completion of table
% names is possible because the table names are added as dynamic properties
% of TableAccessor.
classdef TableAccessor < dynamicprops
    
    methods
        
        function self = TableAccessor(schema)
            for className = schema.classNames
                splitName = strsplit(className{1}, '.');
                name = splitName{2};
                addprop(self, name);
                tableName = schema.tableNames(className{1});
                tierClass = dj.Schema.tierClasses{2}; % default to Manual table
                for k=1:numel(dj.Schema.tierPrefixes)
                    tierCharLen = length(dj.Schema.tierPrefixes{k});
                    if tierCharLen > 0 && ~isempty(regexp(dj.Schema.tierPrefixes{k}, tableName(1:tierCharLen), 'ONCE'))
                        tierClass = dj.Schema.tierClasses{k};
                        break;
                    end
                end
                tierClass = strsplit(tierClass, '.');
                self.(name) = dj.(tierClass{2})(className{1});
            end
        end
    end
    
end
