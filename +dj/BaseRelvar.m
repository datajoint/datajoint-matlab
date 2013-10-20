% dj.BaseRelvar - a relational variable linked to a table in the database.
% BaseRelvar provides data manipulation operators del and insert.
%
% SYNTAX:
%    obj = dj.BaseRelvar(table)  % table must be of class dj.Table

classdef BaseRelvar < dj.GeneralRelvar
    
    properties(Dependent,Access=private)
        tab     % associated table
    end
    
    methods
        function self = init(self, table)
            switch true
                case isa(table, 'dj.Table')
                    init@dj.GeneralRelvar(self, 'table', {table});
                case isa(table, 'dj.BaseRelvar')
                    init@dj.GeneralRelvar(self, 'table', {table.tab}, table.restrictions);
                otherwise
                    dj.assert(false, 'BaseRelvar requires a dj.Table object')
            end
        end
        
        
        function info = get.tab(self)
            info = self.operands{1};
        end
        
        
        function delQuick(self)
            % dj.BaseRelvar/delQuick - remove all tuples of the relation from its table.
            % Unlike dj.BaseRelvar/del, delQuick does not prompt for user
            % confirmation, nor does it attempt to cascade down to the dependent tables.
            self.schema.conn.query(sprintf('DELETE FROM %s', self.sql))
        end
        
        
        function del(self)
            % dj.BaseRelvar/del - remove all tuples of the relation from its table
            % and, recursively, all matching tuples in dependent tables.
            %
            % A summary of the data to be removed will be provided followed by
            % an interactive confirmation before deleting the data.
            %
            % EXAMPLES:
            %   del(common.Scans) % delete all tuples from table Scans and all tuples in dependent tables.
            %   del(common.Scans & 'mouse_id=12') % delete all Scans for mouse 12
            %   del(common.Scans - tp.Cells)  % delete all tuples from table common.Scans
            %                                   that do not have matching tuples in table Cells
            %
            % See also dj.BaseRelvar/delQuick, dj.Table/drop
            
            self.schema.conn.cancelTransaction  % exit ongoing transaction, if any
            
            if ~self.exists
                disp 'nothing to delete'
            else
                % warn the user if deleting from a subtable
                if ismember(self.tab.info.tier, {'imported','computed'}) ...
                        && ~isa(self, 'dj.AutoPopulate')
                    fprintf(['!!! %s is a subtable. For referential integrity, ' ...
                        'delete from its parent instead.\n'], class(self))
                    if ~strcmpi('yes', input('Proceed anyway? yes/no >','s'))
                        disp 'delete cancelled'
                        return
                    end
                end
                
                % compile the list of relvars to be deleted from
                list = self.tab.descendants;
                rels = cellfun(@(name) init(dj.BaseRelvar, dj.Table(name)), list, 'UniformOutput', false);
                rels = [rels{:}];
                
                % apply proper restrictions
                restrictByMe = arrayfun(@(rel) any(ismember(rel.tab.references, list)), rels);  % restrict by all association tables
                restrictByMe(1) = ~isempty(self.restrictions); % if self has restrictions, then restrict by self
                for i=1:length(rels)
                    for ix = cellfun(@(child) find(strcmp(child,list)), [rels(i).tab.children rels(i).tab.referencing])
                        if restrictByMe(i)
                            rels(ix).restrict(rels(i));
                        else
                            rels(ix).restrict(rels(i).restrictions{:});
                        end
                    end
                end
                
                fprintf '\nABOUT TO DELETE:'
                for rel=rels
                    fprintf('\n%8d tuples from %s (%s)', rel.count, rel.tab.fullTableName, rel.tab.info.tier)
                end
                fprintf \n\n
                
                % confirm and delete
                if ~dj.set('suppressPrompt') && ~strcmpi('yes', input('Proceed to delete? yes/no >', 's'))
                    disp 'delete canceled'
                else
                    self.schema.conn.startTransaction
                    try
                        for rel = fliplr(rels)
                            fprintf('Deleting from %s\n', rel.tab.className)
                            rel.delQuick
                        end
                        self.schema.conn.commitTransaction
                        disp committed
                    catch err
                        fprintf '\n ** delete rolled back due to to error\n'
                        self.schema.conn.cancelTransaction
                        rethrow(err)
                    end
                end
            end
        end
        
        
        function insert(self, tuples, command)
            % insert an array of tuples directly into the table
            %
            % The input argument tuples must a structure array with field
            % names exactly matching those in the table.
            %
            % The optional argument 'command' allows replacing the MySQL
            % command from the default INSERT to INSERT IGNORE or REPLACE.
            %
            % Duplicates, unmatched attributes, or missing required attributes will
            % cause an error, unless command is specified.
            
            dj.assert(isstruct(tuples), 'Tuples must be a non-empty structure array')
            if isempty(tuples)
                return
            end
            if nargin<=2
                command = 'INSERT';
            end
            dj.assert(any(strcmpi(command,{'INSERT', 'INSERT IGNORE', 'REPLACE'})), ...
                'invalid insert command')
            header = self.tab.header;
            
            % validate header
            fnames = fieldnames(tuples);
            found = ismember(fnames,{header.name});
            dj.assert(all(found), 'Field %s is not found in the table %s', ...
                fnames{find(~found,1,'first')}, class(self))
            
            % form query
            ix = ismember({header.name}, fnames);
            for tuple=tuples(:)'
                queryStr = '';
                blobs = {};
                for i = find(ix)
                    v = tuple.(header(i).name);
                    if header(i).isString
                        dj.assert(ischar(v), ...
                            'The field %s must be a character string', ...
                            header(i).name)
                        if isempty(v)
                            queryStr = sprintf('%s`%s`="",', ...
                                queryStr, header(i).name);
                        else
                            queryStr = sprintf('%s`%s`="{S}",', ...
                                queryStr,header(i).name);
                            blobs{end+1} = v;  %#ok<AGROW>
                        end
                    elseif header(i).isBlob
                        queryStr = sprintf('%s`%s`="{M}",', ...
                            queryStr,header(i).name);
                        blobs{end+1} = v;    %#ok<AGROW>
                    else
                        if islogical(v)  % mym doesn't accept logicals - save as unit8 instead
                            v = uint8(v);
                        end
                        dj.assert(isscalar(v) && isnumeric(v),...
                            'The field %s must be a numeric scalar value', ...
                            header(i).name)
                        if ~isnan(v)  % nans are not passed: assumed missing.
                            if strcmp(header(i).type, 'bigint')
                                queryStr = sprintf('%s`%s`=%d,',...
                                    queryStr, header(i).name, v);
                            elseif strcmp(header(i).type, 'bigint unsigned')
                                queryStr = sprintf('%s`%s`=%u,',...
                                    queryStr, header(i).name, v);
                            else
                                queryStr = sprintf('%s`%s`=%1.16g,',...
                                    queryStr, header(i).name, v);
                            end
                        end
                    end
                end
                
                % issue query
                self.schema.conn.query( sprintf('%s %s SET %s', ...
                    command, self.tab.fullTableName, ...
                    queryStr(1:end-1)), blobs{:})
            end
        end
        
        
        function inserti(self, tuples)
            % insert tuples but ignore errors. This is useful for rare
            % applications when duplicate entries should be quitely
            % discarded, for example.
            self.insert(tuples, 'INSERT IGNORE')
        end
        
        
        function update(self, attrname, value)
            % dj.BaseRelvar/update - update a field in an existing tuple
            %
            % Relational database maintain referential integrity on the level
            % of a tuple. Therefore, the UPDATE operator can violate referential
            % integrity and should not be used routinely.  The proper way
            % to update information is to delete the entire tuple and
            % insert the entire update tuple.
            %
            % Safety constraints:
            %    1. self must be restricted to exactly one tuple
            %    2. the update attribute must not be in primary key
            %
            % EXAMPLES:
            %   update(v2p.Mice & key, 'mouse_dob',   '2011-01-01')
            %   update(v2p.Scan & key, 'lens')   % set the value to NULL
            
            dj.assert(count(self)==1, 'Update is only allowed on one tuple at a time')
            isNull = nargin<3;
            header = self.header;
            ix = find(strcmp(attrname,{header.name}));
            dj.assert(numel(ix)==1, 'invalid attribute name')
            dj.assert(~header(ix).iskey, 'cannot update a key value. Use insert(..,''REPLACE'') instead')
            
            switch true
                case isNull
                    queryStr = 'NULL';
                    value = {};
                    
                case header(ix).isString
                    dj.assert(ischar(value), 'Value must be a string')
                    queryStr = '"{S}"';
                    value = {value};
                case header(ix).isBlob
                    if isempty(value) && header(ix).isnullable
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = '"{M}"';
                        if islogical(value)
                            value = uint8(value);
                        end
                        value = {value};
                    end
                case header(ix).isNumeric
                    if islogical(value)
                        value = uint8(value);
                    end
                    dj.assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    if isnan(value)
                        dj.assert(header(ix).isnullable, ...
                            'attribute `%s` is not nullable. NaNs not allowed', attrname)
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = sprintf('%1.16g',value);
                        value = {};
                    end
                otherwise
                    dj.assert(false)
            end
            
            queryStr = sprintf('UPDATE %s SET `%s`=%s %s', ...
                self.tab.fullTableName, attrname, queryStr, self.whereClause);
            self.schema.conn.query(queryStr, value{:})
        end
    end
end
