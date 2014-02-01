% Relvar: a relational variable associated with a table in the database and a
% MATLAB class in the schema.


classdef Relvar < dj.GeneralRelvar & dj.Table
    
    methods
        function self = Relvar(varargin)
            self@dj.Table(varargin{:})
            self.init('table',{self});
        end
        
        function yes = isSubtable(self)
            % a subtable is an imported or computed tables that does not
            % have its own auto-populate functionality.
            yes = ismember(self.tableHeader.info.tier, {'imported','computed'}) && ...
                ~isa(self, 'dj.AutoPopulate');
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
                if ismember(self.info.tier, {'imported','computed'}) ...
                        && ~isa(self, 'dj.AutoPopulate')
                    fprintf(['!!! %s is a subtable. For referential integrity, ' ...
                        'delete from its parent instead.\n'], class(self))
                    if ~dj.set('suppressPrompt') && ~strcmpi('yes', dj.ask('Proceed anyway?'))
                        disp 'delete cancelled'
                        return
                    end
                end
                
                % compile the list of relvars to be deleted from
                list = self.descendants;
                rels = cellfun(@(name) dj.Relvar(name), list, 'UniformOutput', false);
                rels = [rels{:}];
                rels(1) = rels(1) & self.restrictions;
                
                % apply proper restrictions
                restrictByMe = arrayfun(@(rel) ...
                    any(ismember(...
                    cellfun(@(r) self.schema.conn.tableToClass(r), rel.referenced,'uni',false),...
                    list)),...
                    rels);  % restrict by all association tables, i.e. tables that make referenced to other tables
                restrictByMe(1) = ~isempty(self.restrictions); % if self has restrictions, then restrict by self
                for i=1:length(rels)
                    % iterate through all tables that reference rels(i)
                    for ix = cellfun(@(child) find(strcmp(self.schema.conn.tableToClass(child),list)), [rels(i).children rels(i).referencing])
                        % and restrict them by it or its restrictions
                        if restrictByMe(i)
                            rels(ix).restrict(rels(i));
                        else
                            rels(ix).restrict(rels(i).restrictions{:});
                        end
                    end
                end
                
                fprintf '\nABOUT TO DELETE:'
                counts = nan(size(rels));
                for i=1:numel(rels)
                    counts(i) = rels(i).count;
                    if counts(i)
                        fprintf('\n%8d tuples from %s (%s)', counts(i), rels(i).fullTableName, rels(i).info.tier)
                    end
                end
                fprintf \n\n
                rels = rels(counts>0);
                
                % confirm and delete
                if ~dj.set('suppressPrompt') && ~strcmpi('yes',dj.ask('Proceed to delete?'))
                    disp 'delete canceled'
                else
                    self.schema.conn.startTransaction
                    try
                        for rel = fliplr(rels)
                            fprintf('Deleting from %s\n', rel.className)
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
            
            assert(isstruct(tuples), 'Tuples must be a non-empty structure array')
            if isempty(tuples)
                return
            end
            if nargin<=2
                command = 'INSERT';
            end
            assert(any(strcmpi(command,{'INSERT', 'INSERT IGNORE', 'REPLACE'})), ...
                'invalid insert command')
            header = self.header;
            
            % validate header
            fnames = fieldnames(tuples);
            found = ismember(fnames,header.names);
            assert(all(found), 'Field %s is not found in the table %s', ...
                fnames{find(~found,1,'first')}, class(self))
            
            % form query
            ix = ismember(header.names, fnames);
            for tuple=tuples(:)'
                queryStr = '';
                blobs = {};
                for i = find(ix)
                    v = tuple.(header.attributes(i).name);
                    if header.attributes(i).isString
                        assert(ischar(v), ...
                            'The field %s must be a character string', ...
                            header.attributes(i).name)
                        if isempty(v)
                            queryStr = sprintf('%s`%s`="",', ...
                                queryStr, header.attributes(i).name);
                        else
                            queryStr = sprintf('%s`%s`="{S}",', ...
                                queryStr,header.attributes(i).name);
                            blobs{end+1} = v;  %#ok<AGROW>
                        end
                    elseif header.attributes(i).isBlob
                        queryStr = sprintf('%s`%s`="{M}",', ...
                            queryStr,header.attributes(i).name);
                        blobs{end+1} = v;    %#ok<AGROW>
                    else
                        if islogical(v)  % mym doesn't accept logicals - save as unit8 instead
                            v = uint8(v);
                        end
                        assert(isscalar(v) && isnumeric(v),...
                            'The field %s must be a numeric scalar value', ...
                            header.attributes(i).name)
                        if ~isnan(v)  % nans are not passed: assumed missing.
                            if strcmp(header.attributes(i).type, 'bigint')
                                queryStr = sprintf('%s`%s`=%d,',...
                                    queryStr, header.attributes(i).name, v);
                            elseif strcmp(header.attributes(i).type, 'bigint unsigned')
                                queryStr = sprintf('%s`%s`=%u,',...
                                    queryStr, header.attributes(i).name, v);
                            else
                                queryStr = sprintf('%s`%s`=%1.16g,',...
                                    queryStr, header.attributes(i).name, v);
                            end
                        end
                    end
                end
                
                % issue query
                self.schema.conn.query( sprintf('%s %s SET %s', ...
                    command, self.fullTableName, ...
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
            
            assert(count(self)==1, 'Update is only allowed on one tuple at a time')
            isNull = nargin<3;
            header = self.header;
            ix = find(strcmp(attrname,header.names));
            assert(numel(ix)==1, 'invalid attribute name')
            assert(~header.attributes(ix).iskey, 'cannot update a key value. Use insert(..,''REPLACE'') instead')
            
            switch true
                case isNull
                    queryStr = 'NULL';
                    value = {};
                case header.attributes(ix).isString
                    assert(ischar(value), 'Value must be a string')
                    queryStr = '"{S}"';
                    value = {value};
                case header.attributes(ix).isBlob
                    if isempty(value) && header.attributes(ix).isnullable
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = '"{M}"';
                        value = {value};
                    end
                case header.attributes(ix).isNumeric
                    assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    if isnan(value)
                        assert(header.attributes(ix).isnullable, ...
                            'attribute `%s` is not nullable. NaNs not allowed', attrname)
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = sprintf('%1.16g',value);
                        value = {};
                    end
                otherwise
                    error 'invalid upate command'
            end
            
            queryStr = sprintf('UPDATE %s SET `%s`=%s %s', ...
                self.fullTableName, attrname, queryStr, self.whereClause);
            self.schema.conn.query(queryStr, value{:})
        end
        
    end
end
