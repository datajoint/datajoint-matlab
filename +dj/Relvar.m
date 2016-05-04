% Relvar: a relational variable associated with a table in the database and a
% MATLAB class in the schema.


classdef Relvar < dj.GeneralRelvar & dj.Table
    
    properties(Dependent, SetAccess = private)
        lastInsertID        % Value of Last auto_incremented primary key
    end
    
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
        
        function id = get.lastInsertID(self)
            % query MySQL for the last auto_incremented key
            ret = query(self.schema.conn, 'SELECT last_insert_id() as `lid`');
            id = ret.lid;
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
                            rels(ix).restrict(pro(rels(i)))
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
        
        
        function exportCascade(self, path,  mbytesPerFile)
            % dj.BaseRelvar/export_cascade - export all tuples of the
            % relation and, recursively, all matching tuples in the
            % dependent tables.
            %
            % See also dj.GeneralRelvar/export
            
            if nargin<2
                path = './temp';
            end
            if nargin<3
                mbytesPerFile = 250;
            end
            
            if ~self.exists
                disp 'nothing to export'
            else
                % compile the list of relvars to be export from
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
                counts = zeros(size(rels));
                for i=1:length(rels)
                    % iterate through all tables that reference rels(i)
                    for ix = cellfun(@(child) find(strcmp(self.schema.conn.tableToClass(child),list)), [rels(i).children rels(i).referencing])
                        % and restrict them by it or its restrictions
                        if restrictByMe(i)
                            rels(ix).restrict(pro(rels(i)))
                        else
                            rels(ix).restrict(rels(i).restrictions{:});
                        end
                    end
                    counts(i) = rels(i).count;
                end
                
                % eliminate all empty relations
                rels = rels(counts>0);
                
                % save
                for rel = rels
                    rel.export(fullfile(path, rel.className), mbytesPerFile);
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
            
            if isa(tuples,'cell')
                % if a cell array, convert to structure assuming matching attributes
                tuples = cell2struct(tuples, self.header.names, 2);
            end
            
            assert(isstruct(tuples), 'Tuples must be a structure array')
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
            if any(~found)
                if dj.set('ignore_extra_insert_fields')
                    tuples = rmfield(tuples, fnames(~found));
                    fnames = fnames(~found);
                else
                    throw(MException('DataJoint:invalidInsert',...
                        'Field %s is not found in the table %s', ...
                        fnames{find(~found,1,'first')}, class(self)))
                end
            end
            
            % form query
            ix = ismember(header.names, fnames);
            fields = sprintf(',`%s`',header.names{ix});
            command = sprintf('%s INTO %s (%s) VALUES ', command, self.fullTableName, fields(2:end));
            blobs = {};
            for tuple=tuples(:)'
                valueStr = '';
                for i = find(ix)
                    v = tuple.(header.attributes(i).name);
                    if header.attributes(i).isString
                        assert(ischar(v), ...
                            'The field %s must be a character string', ...
                            header.attributes(i).name)
                        if isempty(v)
                            valueStr = sprintf('%s"",',valueStr);
                        else
                            valueStr = sprintf('%s"{S}",', valueStr);
                            blobs{end+1} = v;  %#ok<AGROW>
                        end
                    elseif header.attributes(i).isBlob
                        valueStr = sprintf('%s"{M}",', valueStr);
                        blobs{end+1} = v;    %#ok<AGROW>
                    else
                        assert((isnumeric(v) || islogical(v)) && (isscalar(v) || isempty(v)),...
                            'The field %s must be a numeric scalar value', ...
                            header.attributes(i).name)
                        if isempty(v) || isnan(v) % empty numeric values and nans are passed as nulls
                            valueStr = sprintf('%sNULL,', valueStr);
                        elseif isinf(v)
                            error 'Infinite values are not allowed in numeric fields'
                        else  % numeric values
                            type = header.attributes(i).type;
                            if length(type)>=3 && strcmpi(type(end-2:end),'int')
                                valueStr = sprintf('%s%d,', valueStr, v);
                            elseif length(type)>=12 && strcmpi(type(end-11:end),'int unsigned')
                                valueStr = sprintf('%s%u,', valueStr, v);
                            else
                                valueStr = sprintf('%s%1.16g,',valueStr, v);
                            end
                        end
                    end
                end
                command = sprintf('%s(%s),', command, valueStr(1:end-1));
            end
            % issue query
            command(end)=0;
            self.schema.conn.query(command, blobs{:});
        end
        
        
        function inserti(self, tuples)
            % insert tuples but ignore errors. This is useful for rare
            % applications when duplicate entries should be quietly
            % discarded, for example.
            self.insert(tuples, 'INSERT IGNORE')
        end
        
        
        function insertParallel(self, varargin)
            % inserts in a parallel THREAD but waits if the previous insert
            % has not completed yet.  Thus insertParallel uses at most one
            % parallel thread.  Call with no arguments to wait for the last
            % job to complete.
            %
            % Initialize the parallel pool before inserting as parpool('local',1), for example.
            %
            % Requires MATLAB R2013b or later.
            
            persistent THREAD
            if ~isempty(THREAD)
                thread = THREAD;
                THREAD = [];  % clear the job in case there was an error
                thread.fetchOutputs  % wait to complete previous insert
            end
            pool = gcp('nocreate');
            assert(~isempty(pool), ...
                'A parallel pool must be created first, e.g. parpool(''local'',1')
            if nargin>=2
                THREAD = parfeval(pool, @self.insert, 0, varargin{:});
            end
        end
        
        
        function import(self, fileMask)
            % dj.Relvar/import -- load data into one table from .mat files
            % See also dj.GeneralRelvar/export
            countTuples = 0;
            for f = dir(fileMask)'
                fprintf('Reading file %s  ', f.name)
                s = load(f.name);
                self.insert(s.tuples)
                countTuples = countTuples + numel(s.tuples);
                fprintf(' %7d tuples\n', countTuples)
            end
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
                    valueStr = 'NULL';
                    value = {};
                case header.attributes(ix).isString
                    assert(ischar(value), 'Value must be a string')
                    valueStr = '"{S}"';
                    value = {value};
                case header.attributes(ix).isBlob
                    if isempty(value) && header.attributes(ix).isnullable
                        valueStr = 'NULL';
                        value = {};
                    else
                        valueStr = '"{M}"';
                        value = {value};
                    end
                case header.attributes(ix).isNumeric
                    assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    if isnan(value)
                        assert(header.attributes(ix).isnullable, ...
                            'attribute `%s` is not nullable. NaNs not allowed', attrname)
                        valueStr = 'NULL';
                        value = {};
                    else
                        valueStr = sprintf('%1.16g',value);
                        value = {};
                    end
                otherwise
                    error 'invalid update command'
            end
            
            valueStr = sprintf('UPDATE %s SET `%s`=%s %s', ...
                self.fullTableName, attrname, valueStr, self.whereClause);
            self.schema.conn.query(valueStr, value{:})
        end
    end
    
    methods(Static)
        function importAll(path)
            % Import all files from path/schema.ClassName-*.mat
            % The files are first sorted in order of dependencies.
            % Their contents are then inserted in order of dependencies.
            
            s = dir(fullfile(path,'*-*.mat'));
            if isempty(s)
                warning 'no matching files found'
                return
            end
            
            % create all tables
            disp Declaring..
            relvars = {};
            conn = [];
            for f = {s.name}
                tableName = f{1}(1:find(f{1}=='-',1,'first')-1);
                %make sure all schemas are loaded
                if exist(tableName, 'class')
                    r = feval(tableName);  % instantiate
                    conn = r.conn;
                    relvars{end+1} = r; %#ok<AGROW>
                    assert(isa(r, 'dj.Relvar'), ...
                        'class %s must be a Relvar', tableName)
                    r.info;  % create tables if not yet created
                else
                    warning('%s is not found', tableName)
                end
            end
            
            % populate tables in order of dependence
            disp Inserting..
            names = cellfun(@(r) r.fullTableName, relvars, 'uni', false);
            C = conn.makeDependencyMatrix(names);
            levels = dj.Connection.computeHierarchyLevels(C);
            for level=0:max(levels)
                for i=find(levels(:)' == level)
                    disp(s(i).name)
                    contents = load(fullfile(path, s(i).name));
                    relvars{i}.inserti(contents.tuples);
                end
            end
        end
    end
end
