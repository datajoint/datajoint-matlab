classdef BaseRelvar < dj.GeneralRelvar
    % BaseRelvar: a relational variable linked to a table in the database.
    % BaseRelvar provides data manipulation operators del and insert.
    %
    % SYNTAX:
    %    obj = dj.BaseRelvar(table)  % table must be of class dj.Table
    
    properties(Dependent,Access=private)
        tab     % associated table
    end
    
    methods
        function self = init(self, table)
            assert(isa(table, 'dj.Table'))
            init@dj.GeneralRelvar(self, 'table', {table});
        end
        
        
        function info = get.tab(self)
            info = self.operands{1};
        end
        
        
        function del(self, doPrompt)
            % dj.BaseRelvar/del - remove all tuples of relation self from its table
            % as well as all dependent tuples in dependent tables.
            %
            % By default, confirmation is requested before deleting the data.
            % To turn off the confirmation, set the second input doPrompt to false.
            %
            % EXAMPLES:
            %   del(Scans) % delete all tuples from table Scans and all tuples in dependent tables.
            %   del(Scans('mouse_id=12')) % delete all Scans for mouse 12
            %   del(Scans - Cells)  % delete all tuples from table Scans that do not have matching
            %                       % tuples in table Cells
            %
            % See also dj.Table/drop
            
            doPrompt = nargin<2 || doPrompt;
            self.schema.conn.cancelTransaction  % exit ongoing transaction, if any
            
            if self.count==0
                disp 'nothing to delete'
            else
                % warn the user if deleting from a subtable
                if ismember(self.tab.info.tier, {'imported','computed'}) ...
                        && ~isa(self, 'dj.AutoPopulate')
                    fprintf(['!!! %s is a subtable. For referential integrity, ' ...
                        'delete from its parent instead.\n'], class(self))
                    if ~strcmpi('yes', input('Prceed anyway? yes/no >','s'))
                        disp 'delete cancelled'
                        return
                    end
                end
                
                % get the names of the dependent tables
                names = self.tab.getNeighbors(0, +1000, false);
                names = self.schema.conn.getPackage(names);
                
                % construct relvars to delete restricted by self
                rels = {self};
                for i=2:length(names)
                    rels{end+1} = init(dj.BaseRelvar, dj.Table(names{i})) & self; %#ok:<AGROW>
                end
                clear names
                
                % exclude relvar with no matching tuples
                counts = cellfun(@(x) count(x), rels);
                include =  counts > 0;
                counts = counts(include);
                rels = rels(include);
                
                % inform the  user about what's being deleted
                if doPrompt
                    disp 'ABOUT TO DELETE:'
                    for iRel = 1:length(rels)
                        fprintf('%s %s: %d', ...
                            rels{iRel}.tab.info.tier, ...
                            rels{iRel}.tab.info.name, counts(iRel));
                        if ismember(rels{iRel}.tab.info.tier, {'manual','lookup'})
                            fprintf ' !!!'
                        end
                        fprintf \n
                    end
                    fprintf \n
                end
                
                % confirm and delete
                if doPrompt && ~strcmpi('yes', input('Proceed to delete? yes/no >', 's'))
                    disp 'delete canceled'
                else
                    self.schema.conn.startTransaction
                    try
                        for iRel = length(rels):-1:1
                            fprintf('Deleting %d tuples from %s... ', ...
                                counts(iRel), rels{iRel}.tab.className)
                            self.schema.conn.query(sprintf('DELETE FROM `%s`.`%s`%s', ...
                                rels{iRel}.schema.dbname, rels{iRel}.tab.info.name, self.whereClause))
                            fprintf 'done (not committed)\n'
                        end
                        self.schema.conn.commitTransaction
                        fprintf ' ** delete committed\n'
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
            % Duplicates, unmatched attrs, or missing required attrs will
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
            attrs = self.attrs;
            
            % validate attrs
            fnames = fieldnames(tuples);
            found = ismember(fnames,{attrs.name});
            if ~all(found)
                error('Field %s is not found in the table %s', ...
                    fnames{find(~found,1,'first')}, class(self));
            end
            
            % form query
            ix = ismember({attrs.name}, fnames);
            for tuple=tuples(:)'
                queryStr = '';
                blobs = {};
                for i = find(ix)
                    v = tuple.(attrs(i).name);
                    if attrs(i).isString
                        assert(ischar(v), ...
                            'The field %s must be a character string', ...
                            attrs(i).name)
                        if isempty(v)
                            queryStr = sprintf('%s`%s`="",', ...
                                queryStr, attrs(i).name);
                        else
                            queryStr = sprintf('%s`%s`="{S}",', ...
                                queryStr,attrs(i).name);
                            blobs{end+1} = v;  %#ok<AGROW>
                        end
                    elseif attrs(i).isBlob
                        queryStr = sprintf('%s`%s`="{M}",', ...
                            queryStr,attrs(i).name);
                        if islogical(v) % mym doesn't accept logicals - save as uint8 instead
                            v = uint8(v);
                        end
                        blobs{end+1} = v;    %#ok<AGROW>
                    else
                        if islogical(v)  % mym doesn't accept logicals - save as unit8 instead
                            v = uint8(v);
                        end
                        assert(isscalar(v) && isnumeric(v),...
                            'The field %s must be a numeric scalar value', ...
                            attrs(i).name)
                        if ~isnan(v)  % nans are not passed: assumed missing.
                            queryStr = sprintf('%s`%s`=%1.16g,',...
                                queryStr, attrs(i).name, v);
                        end
                    end
                end
                
                % issue query
                self.schema.conn.query( sprintf('%s `%s`.`%s` SET %s', ...
                    command, self.schema.dbname, self.tab.info.name, ...
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
            %   update(v2p.Mice(key), 'mouse_dob',   '2011-01-01')
            %   update(v2p.Scan(key), 'lens')   % set the value to NULL
            
            assert(count(self)==1, 'Update is only allowed on one tuple at a time')
            isNull = nargin<3;
            attrs = self.attrs;
            ix = find(strcmp(attrname,{attrs.name}));
            assert(numel(ix)==1, 'invalid attribute name')
            assert(~attrs(ix).iskey, 'cannot update a key value. Use insert(..,''REPLACE'') instead')
            
            switch true
                case isNull
                    queryStr = 'NULL';
                    value = {};
                    
                case attrs(ix).isString
                    assert(ischar(value), 'Value must be a string')
                    queryStr = '"{S}"';
                    value = {value};
                case attrs(ix).isBlob
                    if isempty(value) && attrs(ix).isnullable
                        queryStr = NULL;
                        value = {};
                    else
                        queryStr = '"{M}"';
                        if islogical(value)
                            value = uint8(value);
                        end
                        value = {value};
                    end
                case attrs(ix).isNumeric
                    if islogical(value)
                        value = uint8(valuealue);
                    end
                    assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    if isnan(value)
                        assert(attrs(ix).isnullable, ...
                            'attribute `%s` is not nullable. NaNs not allowed', attrname)
                        queryStr = 'NULL';
                        value = {};
                    else
                        queryStr = sprintf('%1.16g',value);
                        value = {};
                    end
                otherwise
                    error 'Invalid condition: please report to DataJoint developers'
            end
            
            queryStr = sprintf('UPDATE `%s`.`%s` SET `%s`=%s %s', ...
                self.schema.dbname, self.tab.info.name, attrname, queryStr, self.whereClause);
            self.schema.conn.query(queryStr, value{:})
        end
    end
end
