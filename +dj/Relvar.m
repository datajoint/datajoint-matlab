% Relvar: a relational variable associated with a table in the database and a
% MATLAB class in the schema.
%
% Relvar is an abstract class. Users must derive a subclass
% <package>.<ClassName> with the constant property
% table = dj.Table('<package>.<TableName>)


classdef Relvar < dj.BaseRelvar & dj.Table
    
    methods        
        function yes = isSubtable(self)
            % a subtable is an imported or computed tables that does not
            % have its own auto-populate functionality.
            yes = ismember(self.table.info.tier, {'imported','computed'}) && ...
                ~isa(self, 'dj.AutoPopulate');
        end        
    end
 
end