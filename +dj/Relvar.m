% Relvar: a relational variable associated with a table in the database and a 
% MATLAB class in the schema.
%
% Relvar is an abstract class. Users must derive a subclass
% <package>.<ClassName> with the constant property 
% table = dj.Table('<package>.<TableName>)
%
% To declare a base relvar without declaring a class, use
% dj.BaseRelvar('<package>.<TableName>')


classdef Relvar < dj.BaseRelvar
    
    properties(Abstract,Constant)
        table    % all derived classes must declare this property
    end
    
    methods
        
        function self = Relvar()
            self.init(self.table);
        end
            
        function yes = isSubtable(self)
            % a subtable is an imported or computed tables that does not
            % have its own auto-populate functionality.
            yes = ismember(self.table.info.tier, {'imported','computed'}) && ...
                ~isa(self, 'dj.AutoPopulate') && ~isa(self, 'dj.Automatic');
        end        
    end
end
