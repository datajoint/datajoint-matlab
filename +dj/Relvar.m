% Relvar: a relational variable associated with a table in the database and a
% MATLAB class in the schema.


classdef Relvar < dj.internal.GeneralRelvar & dj.internal.Table
    
    properties(Dependent, SetAccess = private)
        lastInsertID        % Value of Last auto_incremented primary key
    end
    
    methods
        function self = Relvar(varargin)
            self@dj.internal.Table(varargin{:})
            self.init('table', {self});  % general relvar node
        end
        
        function id = get.lastInsertID(self)
            % query MySQL for the last auto_incremented key
            ret = query(self.schema.conn, 'SELECT last_insert_id() as `lid`');
            id = ret.lid;
        end
        
        function count = delQuick(self, getCount)
            % DELQUICK - remove all tuples of the relation from its table.
            % Unlike del, delQuick does not prompt for user
            % confirmation, nor does it attempt to cascade down to the dependent tables.
            self.schema.conn.query(sprintf('DELETE FROM %s', self.sql))
            count = [];
            if nargin > 1 && getCount
                count = self.schema.conn.query(sprintf('SELECT count(*) as count FROM %s', ...
                    self.sql)).count;
            end
        end
        
        
        function del(self,maintainTransaction)
            % DEL - remove all tuples of the relation from its table
            % and, recursively, all matching tuples in dependent tables.
            %
            % A summary of the data to be removed will be provided followed by
            % an interactive confirmation before deleting the data.
            %
            % EXAMPLES:
            %   del(common.Scans) % delete all tuples from table Scans and all tuples
            %                       in dependent tables.
            %   del(common.Scans & 'mouse_id=12') % delete all Scans for mouse 12
            %   del(common.Scans - tp.Cells)  % delete all tuples from table common.Scans
            %                                   that do not have matching tuples in table 
            %                                   Cells
            % See also delQuick, drop

            function cleanup(self, maintainTransaction)
                if self.schema.conn.inTransaction && ~maintainTransaction
                    fprintf '\n ** delete rolled back due to an interrupt\n'
                    self.schema.conn.cancelTransaction
                end
            end

            if nargin<2
                maintainTransaction = false;
            end

            % this is guaranteed to be executed when the function is
            % terminated even if by KeyboardInterrupt (CTRL-C)
            cleanupObject = onCleanup(@() cleanup(self, maintainTransaction));
            
            if ~maintainTransaction
                self.schema.conn.cancelTransaction  % exit ongoing transaction, if any
            end

            if ~self.exists
                disp 'nothing to delete'
            elseif any(strcmp(superclasses(self),'dj.Part'))
                disp 'cannot delete directly from part table'
            else
                % compile the list of relvars to be deleted from
                list = self.descendants;
                rels = cellfun(@(name) dj.Relvar(name), list, 'UniformOutput', false);
                rels = [rels{:}];
                rels(1) = rels(1) & self.restrictions;
                
                % apply proper restrictions
                restrictByMe = arrayfun(@(rel) ...
                    any(ismember(...
                    cellfun(@(r) self.schema.conn.tableToClass(r), rel.parents(false), ...
                        'uni',false),...
                    list)),...
                    rels);  % restrict by all association tables, i.e. tables that make
                            % referenced to other tables
                restrictByMe(1) = ~isempty(self.restrictions); % if self has restrictions,
                                                               % then restrict by self
                for i=1:length(rels)
                    % iterate through all tables that reference rels(i)
                    for ix = cellfun(@(child) find(strcmp( ...
                            self.schema.conn.tableToClass(child),list)), rels(i).children)
                        % and restrict them by it or its restrictions
                        if restrictByMe(i)
                            % Extract foreign key indices for table that match target parent
                            fk_index = arrayfun(...
                                @(x) strcmp(x.from, rels(ix).fullTableName), ...
                                self.schema.conn.foreignKeys, 'uni', true);
                            fks = self.schema.conn.foreignKeys(fk_index);
                            if ~any([fks.aliased])
                                % If matched foreign keys are not aliased, no renaming
                                % necessary. Restrict table based on normal projection.
                                rels(ix).restrict(proj(rels(i)));
                            else
                                % Determine which foreign keys have been renamed
                                alias_index = cellfun(...
                                    @(ref_attr, attr) ~strcmp(ref_attr, attr), ...
                                    fks.ref_attrs, fks.attrs, 'uni', true);
                                % Create rename arguments for projection
                                aliased_attrs = cellfun(...
                                    @(ref_attr, attr) sprintf('%s->%s', ref_attr, attr), ...
                                    fks.ref_attrs(alias_index), fks.attrs(alias_index), ...
                                    'uni', false);
                                % Restrict table based on projection with rename arguments on
                                % foreign keys.
                                rels(ix).restrict(proj(rels(i), aliased_attrs{:}));
                            end
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
                        fprintf('\n%8d tuples from %s (%s)', counts(i), ...
                            rels(i).fullTableName, rels(i).info.tier)
                    end
                end
                fprintf \n\n
                rels = rels(counts>0);
                
                % confirm and delete
                if dj.config('safemode') && ~strcmpi('yes', ...
                        dj.internal.ask('Proceed to delete?'))
                    disp 'delete canceled'
                    if maintainTransaction
                        error('Cancelled nested delete of master/part relation.');
                    end
                else
                    if ~maintainTransaction
                        self.schema.conn.startTransaction
                    end
                    try
                        parts = {};
                        partRels = {};
                        for rel = fliplr(rels)
                            fprintf('Deleting from %s\n', rel.className)

                            if any(strcmp(superclasses(rel.className), 'dj.Part'))
                                if strcmp(feval(rel.className).master.className,self.className)
                                    % we want to delete this part with the master
                                    parts = cat(1,parts,{feval(rel.className)});
                                    partRels = cat(1,partRels,{rel});
                                elseif ~strcmp(feval(rel.className).master.className,{rels(:).className})
                                    %the master does not derive from the
                                    %caller, but a part must be deleted
                                    
                                    %must delete the master to maintain
                                    %integrity. Deleting the master will
                                    %delete this part
                                    del(feval(rel.className).master & rel, true);
                                    
                                else
                                    %the master derives from the caller, so
                                    %all is fine
                                    rel.delQuick;
                                end
                            elseif strcmp(rel.className,self.className) && ~isempty(parts)
                                %the current table is a master table
                                %we will delete alongside its parts
                                
                                
                                % self.schema.conn.query(sprintf('DELETE %s,%s FROM %s',...
                                %     feval(rel.className).sql, parts{1}.sql,join.sql));
                                % above doesn't seem to work, due to `ON
                                % DELETE RESTRICT` foreign key
                                
                                % so we will disable the foreign key
                                % temporarily, then do the multi-delete
                                
                                reentries = {};
                                join = feval(rel.className);
                                del_str = join.sql;
                                for n=1:numel(parts)
                                    join = parts{n} * join * partRels{n};
                                    del_str = sprintf('%s,%s',parts{n}.sql,del_str);
                                    fks = splitlines(parts{n}.describe());
                                    tfk = fks(contains(fks, rel.className));
                                    for fk =tfk
                                        % parts{1}.addForeignKey(cell2mat(fk));
                                        [attr_sql, fk_sql, ~, ~] = dj.internal.Declare.makeFK(fk{1}, ...
                                            parts{n}.primaryKey, true, dj.internal.shorthash(parts{n}.fullTableName));
                                        reentries = cat(1, reentries, {sprintf('ALTER TABLE %s ADD %s%s', parts{n}.fullTableName,attr_sql, fk_sql)});
                                    end
                                end
                                
                                for n=1:numel(parts)
                                    name = self.schema.conn.query(sprintf( ...
                                        ['SELECT distinct constraint_name AS name ' ...
                                        'FROM information_schema.key_column_usage ' ...
                                        'WHERE table_schema="%s" and table_name="%s"' ...
                                        'AND referenced_table_schema="%s" ' ...
                                        'AND referenced_table_name="%s"'], ...
                                        parts{n}.schema.dbname, parts{n}.plainTableName, ...
                                        feval(rel.className).schema.dbname, feval(rel.className).plainTableName...
                                        ));
                                    for name_ind = numel(name.name)
                                        % The table could have multiple keys
                                        % referring to the master, so we'll
                                        % drop them all
                                        self.schema.conn.query(sprintf('ALTER TABLE %s DROP FOREIGN KEY `%s`',...
                                            parts{n}.fullTableName, name.name{name_ind}));
                                    end
                                end
                                self.schema.conn.query(sprintf('DELETE %s FROM %s',...
                                    del_str,join.sql));
                                
                                %add back the foreign keys (note that we're
                                %still in the same transaction...)
                                for ind = 1:numel(reentries)
                                    self.schema.conn.query(reentries{ind});
                                end
                            else
                                rel.delQuick;
                            end
                        end
                        if ~maintainTransaction
                            self.schema.conn.commitTransaction
                            disp committed
                        end
                    catch err
                        fprintf '\n ** delete rolled back due to an error\n'
                        self.schema.conn.cancelTransaction
                        rethrow(err)
                    end
                end
            end
        end
        
        
        function exportCascade(self, path,  mbytesPerFile)
            % exportCascade - export all tuples of the
            % relation and, recursively, all matching tuples in the
            % dependent tables.
            %
            % See also export
            
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
                % restrict by all association tables, i.e. tables that make referenced to
                % other tables
                restrictByMe = arrayfun(@(rel) ...
                    any(ismember(cellfun(@(r) self.schema.conn.tableToClass(r), ...
                    rel.parents(false), 'uni', false), list)), rels);
                % if self has restrictions, then restrict by self
                restrictByMe(1) = ~isempty(self.restrictions);
                counts = zeros(size(rels));
                for i=1:length(rels)
                    % iterate through all tables that reference rels(i)
                    for ix = cellfun(@(child) find(strcmp( ...
                            self.schema.conn.tableToClass(child),list)), rels(i).children)
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
            % insert(self, tuples, command)
            %
            % insert an array of tuples directly into the table.
            % The insert is performed as a single query even for multiple
            % inserts. Therefore, it's an all-or-nothing operation: failure
            % to insert any tuple is a failure to insert all tuples.
            %
            % The input argument tuples must a structure array with field
            % names exactly matching those in the table.
            % 
            % The ignoreExtraFields setting in dj.config allows ignoring fields
            % in the tuples structure that are not found in the table.
            %
            % The optional argument 'command' can be of the following:
            % 'IGNORE' or 'REPLACE'.
            %
            % Duplicates, unmatched attributes, or missing required attributes will
            % cause an error, unless 'command' is specified.
            
            function [value, placeholder] = makePlaceholder(attr_idx, value)
                % [value, placeholder] = MAKEPLACEHOLDER(attr_idx, value)
                %   Process in-place data to be inserted and update placeholder.
                %   value:      <var> Processed, in-place value ready for insert.
                %   placeholder:<string> Placeholder for argument substitution.
                %   attr_idx:   <num> Attribute order index.
                if (header.attributes(attr_idx).isNumeric && length(value) == 1 && ...
                        isnan(value)) || (~header.attributes(attr_idx).isNumeric && ...
                        ~ischar(value) && isempty(value))
                    assert(header.attributes(attr_idx).isnullable, ...
                        'DataJoint:DataType:NotNullable', ...
                        'attribute `%s` is not nullable.', ...
                        header.attributes(attr_idx).name);
                    placeholder = 'NULL';
                    value = [];
                elseif header.attributes(attr_idx).isString
                    assert(dj.lib.isString(value), ...
                        'DataJoint:DataType:Mismatch', ...
                        'The field `%s` must be a character string', ...
                        header.attributes(attr_idx).name);
                    placeholder = '"{S}"';
                    value = char(value);
                elseif header.attributes(attr_idx).isUuid
                    value = strrep(value, '-', '');
                    hexstring = value';
                    reshapedString = reshape(hexstring,2,16);
                    hexMtx = reshapedString.';
                    decMtx = hex2dec(hexMtx);
                    placeholder = '"{B}"';
                    value = uint8(decMtx);
                elseif header.attributes(attr_idx).isAttachment || ...
                        header.attributes(attr_idx).isFilepath
                    error('DataJoint:DataType:NotYetSupported', ...
                        'The field `%s` with datatype `%s` is not yet supported.', ...
                        header.attributes(attr_idx).name, header.attributes(attr_idx).type)
                elseif header.attributes(attr_idx).isBlob
                    assert(~issparse(value), ...
                        'DataJoint:DataType:Mismatch', ...
                        'Sparse matrix in blob field `%s` is currently not supported', ...
                        header.attributes(attr_idx).name);
                    if ~header.attributes(attr_idx).isExternal
                        placeholder = '"{M}"';
                    else
                        value = self.schema.external.table(...
                            header.attributes(attr_idx).store).upload_buffer(value);
                        hexstring = value';
                        reshapedString = reshape(hexstring,2,16);
                        hexMtx = reshapedString.';
                        decMtx = hex2dec(hexMtx);
                        placeholder = '"{B}"';
                        value = uint8(decMtx);
                    end
                else
                    assert((isnumeric(value) || islogical(value)) && (isscalar( ...
                        value) || isempty(value)),...
                        'DataJoint:DataType:Mismatch', ...
                        'The field `%s` must be a numeric scalar value', ...
                        header.attributes(attr_idx).name);
                    % empty numeric values and nans are passed as nulls
                    if isinf(value)
                        error 'Infinite values are not allowed in numeric fields'
                    else  % numeric values
                        type = header.attributes(i).type;
                        if length(type)>=3 && strcmpi(type(end-2:end),'int')
                            placeholder = sprintf('%d', value);
                        elseif length(type)>=12 && strcmpi(type(end-11:end),'int unsigned')
                            placeholder = sprintf('%u', value);
                        else
                            placeholder = sprintf('%1.16g', value);
                        end
                        value = [];
                    end
                end
            end

            if isa(tuples,'cell')
                % if a cell array, convert to structure assuming matching attributes
                tuples = cell2struct(tuples, self.header.names, 2);
            end
            
            assert(isstruct(tuples), 'Tuples must be a structure array')
            if isempty(tuples)
                return
            end
            if nargin<=2 || strcmp(command, 'INSERT')
                command = 'INSERT';
            else
                switch command
                    case {'IGNORE','ignore','INSERT IGNORE'}
                        command = 'INSERT IGNORE';
                    case {'REPLACE', 'replace'}
                        command = 'REPLACE';
                    otherwise
                        error('invalid insert option ''%s'': use ''REPLACE'' or ''IGNORE''',...
                            command)
                end
            end
            header = self.header;
            
            % validate header
            fnames = fieldnames(tuples);
            found = ismember(fnames,header.names);
            if any(~found)
                if dj.config('queryIgnore_extra_insert_fields')
                    tuples = rmfield(tuples, fnames(~found));
                    fnames = fnames(found);
                else
                    throw(MException('DataJoint:invalidInsert',...
                        'Field %s is not found in the table %s', ...
                        fnames{find(~found,1,'first')}, class(self)))
                end
            end
            
            % form query
            ix = ismember(header.names, fnames);
            fields = sprintf(',`%s`',header.names{ix});
            command = sprintf('%s INTO %s (%s) VALUES ', command, self.fullTableName, ...
                fields(2:end));
            blobs = {};
            for tuple=tuples(:)'
                valueStr = '';
                for i = find(ix)
                    [v, placeholder] = makePlaceholder(i, tuple.(header.attributes(i).name));
                    if ~isempty(v) || ischar(v)
                        blobs{end+1} = v;   %#ok<AGROW>
                    end
                    valueStr = sprintf(['%s' placeholder ','],valueStr);
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
            % discarded.
            self.insert(tuples, 'IGNORE')
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
            % IMPORT(self, fileMask) - load data into one table from .mat files
            % See also export
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
            % update - update a field in an existing tuple
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
            
            assert(count(self)==1, 'Update is only allowed on one tuple at a time');
            header = self.header;
            ix = find(strcmp(attrname,header.names));
            assert(numel(ix)==1, 'invalid attribute name');
            assert(~header.attributes(ix).iskey, ...
                'cannot update a key value. Use insert(..,''REPLACE'') instead');
            isNull = nargin<3 || (header.attributes(ix).isNumeric && isnan(value)) || ...
                (~header.attributes(ix).isNumeric && ~ischar(value) && isempty(value));
            
            switch true
                case isNull
                    assert(header.attributes(ix).isnullable, ...
                        'attribute `%s` is not nullable.', attrname);
                    valueStr = 'NULL';
                    value = {};
                case header.attributes(ix).isString
                    assert(dj.lib.isString(value), 'Value must be a string');
                    valueStr = '"{S}"';
                    value = {char(value)};
                case header.attributes(ix).isAttachment || header.attributes(ix).isFilepath
                    error('DataJoint:DataType:NotYetSupported', ...
                        'The field `%s` with datatype `%s` is not yet supported.', ...
                        header.attributes(ix).name, header.attributes(ix).type)
                case header.attributes(ix).isBlob
                    assert(~issparse(value), ...
                        'DataJoint:DataType:Mismatch', ...
                        'Sparse matrix in blob field `%s` is currently not supported', ...
                        attrname);
                    valueStr = '"{M}"';
                    value = {value};
                case header.attributes(ix).isNumeric
                    assert(isscalar(value) && isnumeric(value), 'Numeric value must be scalar')
                    valueStr = sprintf('%1.16g',value);
                    value = {};
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
            for i = toposort(conn.makeGraph(names))
                disp(names{i})
                contents = load(fullfile(path, names{i}));
                relvars{i}.inserti(contents.tuples);
            end
        end
    end
end
