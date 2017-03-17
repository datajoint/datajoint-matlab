classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId       % connection handle
        packages     % maps database names to package names
        
        % dependency lookups by table name
        foreignKeys   % maps table names to their referenced table names     (primary foreign key)
    end
    
    properties(Access = private)
        password
    end
    
    properties(Dependent)
        isConnected
    end
    
    methods
        
        function self=Connection(host, username, password, initQuery)
            % specify the connection to the database.
            % initQuery is the SQL query to be executed at the start
            % of each new session.
            try
                mymVersion = mym('version');
                assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6)
            catch
                error 'Outdated version of mYm.  Please upgrade to version 2.6 or later'
            end
            if verLessThan('matlab', '8.6')
                error 'MATLAB version 8.6 (R2015b) or greater is required'
            end
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
            self.foreignKeys  = struct([]);
            self.packages = containers.Map;
        end
        
        
        function addPackage(self, dbname, package)
            self.packages(dbname) = package;
        end
        
        
        function loadDependencies(self, schema)
            % load dependencies from SHOW CREATE TABLE
            pat = cat(2,...
                'FOREIGN KEY\s+\((?<attrs>[`\w, ]+)\)\s+',...  % attrs1
                'REFERENCES\s+(?<ref>[^\s]+)\s+',...        % referenced table name
                '\((?<ref_attrs>[`\w, ]+)\)');
            
            for tabName = schema.headers.keys
                fk = self.query(sprintf('SHOW CREATE TABLE `%s`.`%s`', schema.dbname, tabName{1}));
                fk = strtrim(regexp(fk.('Create Table'){1},'\n','split')');
                fk = regexp(fk, pat, 'names');
                fk = [fk{:}];
                from = sprintf('`%s`.`%s`', schema.dbname, tabName{1});
                
                for s=fk
                    s.from = from;
                    s.ref = s.ref;
                    s.attrs = regexp(s.attrs, '\w+', 'match');
                    s.ref_attrs = regexp(s.ref_attrs, '\w+', 'match');
                    s.primary = all(ismember(s.attrs, schema.headers(tabName{1}).primaryKey));
                    s.multi = ~all(ismember(schema.headers(tabName{1}).primaryKey, s.attrs));
                    if isempty(regexp(s.ref,'`\.`','once'))
                        s.ref = sprintf('`%s`.%s',schema.dbname,s.ref);
                    end
                    s.aliased = ~isequal(s.attrs, s.ref_attrs);
                    self.foreignKeys = [self.foreignKeys, s];
                end
            end
        end
        
        
        function [names, isprimary] = parents(self, child, primary)
            if isempty(self.foreignKeys)
                names = {};
                isprimary = [];
            else
                ix = strcmp(child, {self.foreignKeys.from});
                if nargin>2
                    ix = ix & primary == [self.foreignKeys.primary];
                end
                names = {self.foreignKeys(ix).ref};
                if nargout > 1
                    isprimary = [self.foreignKeys(ix).primary];
                end
            end
        end
        
        
        function [names, isprimary] = children(self, parent, primary)
            if isempty(self.foreignKeys)
                names = {};
                isprimary = [];
            else
                ix = strcmp(parent, {self.foreignKeys.ref});
                if nargin>2
                    ix = ix & primary == [self.foreignKeys.primary];
                end
                names = {self.foreignKeys(ix).from};
                if nargout > 1
                    isprimary = [self.foreignKeys(ix).primary];
                end
            end
        end
        
        
        function className = tableToClass(self, fullTableName, strict)
            % convert '`dbname`.`table_name`' to 'package.ClassName'
            % If strict (false by default), throw error if the dbname is not found.
            % If not strict and the name is not found, then className=tableName
            
            strict = nargin>=3 && strict;
            s = regexp(fullTableName, '^`(?<dbname>.+)`.`(?<tablename>[#~\w\d]+)`$','names');
            className = fullTableName;
            if ~isempty(s) && self.packages.isKey(s.dbname)
                className = sprintf('%s.%s',self.packages(s.dbname),dj.toCamelCase(s.tablename));
            elseif strict
                error('Unknown package for "%s". Activate its schema first.', fullTableName)
            end
        end
        
        
        function erd(self, list, up, down)
            % ERD -- plot the Entity Relationship Diagram
            %
            % INPUTS:
            %    list -- tables to include in the diagram formatted as
            %    `dbname`.`table_name`
            
            if nargin<3
                up = 0;
                down = 0;
            end
            
            % get additional nodes that are connected to ones on the list:
            % up the hierarchy
            lastAdded = list;
            assert(up>=0 && down>=0, 'ERD radius must be positive')
            while up || down
                added = [];
                if up
                    temp = cellfun(@(s) ...
                        self.parents(s), ...
                        lastAdded, 'uni', false);
                    added = setdiff([temp{:}],list);
                    up = up - 1;
                end
                if down
                    temp = cellfun(@(s) ...
                        self.children(s), ...
                        lastAdded, 'uni', false);
                    added = union(added,setdiff([temp{:}],list));
                    down = down - 1;
                end
                list = union(list,added);
                lastAdded = added;
            end
            
            % determine tiers
            % exclude job tables
            j = cellfun(@isempty, regexp(list, '^`[a-z]\w*`\.`~\w+`$'));
            list = list(j);
            
            d = self.makeGraph(list);
            rege = cellfun(@(s) sprintf('^`[a-z]\\w*`\\.`%s[a-z]\\w*`$',s), dj.Schema.tierPrefixes, 'uni', false);
            rege{end+1} = '^`[a-z]\w*`\.`\W?\w+__\w+`$';   % for part tables
            rege{end+1} = '^\d+$';  % for numbered nodes
            tiers = cellfun(@(l) find(~cellfun(@isempty, regexp(l, rege)), 1, 'last'), d.Nodes.Name);
            colormap(0.3+0.7*[
                0.3 0.3 0.3
                0.0 0.5 0.0
                0.0 0.0 1.0
                1.0 0.0 0.0
                1.0 1.0 1.0
                0.0 0.0 0.0
                1.0 0.0 0.0
                ]);
            marker = {'hexagram' 'square' 'o' 'pentagram' '.' '.' '.'};
            d.Nodes.marker = marker(tiers)';
            h = d.plot('layout', 'layered', 'NodeLabel', []);
            h.NodeCData = tiers;
            caxis([0.5 7.5])
            h.MarkerSize = 12;
            h.Marker = d.Nodes.marker;
            axis off
            for i=1:d.numnodes
                if tiers(i)<7  % ignore jobs, logs, etc.
                    isPart = tiers(i)==6;
                    fs = dj.set('erdFontSize')*(1 - 0.3*isPart);
                    fc = isPart*0.3*[1 1 1];
                    text(h.XData(i)+0.1,h.YData(i), self.tableToClass(d.Nodes.Name{i}), ...
                        'fontsize', fs, 'rotation', -16, 'color', fc, ...
                        'Interpreter', 'none');
                end
            end
            if d.numedges
                line_widths = [1 2];
                h.LineWidth = line_widths(2-d.Edges.primary);
                line_styles = {'-', ':'};
                h.LineStyle = line_styles(2-d.Edges.primary);
                ee = cellfun(@(e) find(strcmp(e, d.Nodes.Name), 1, 'first'), d.Edges.EndNodes(~d.Edges.multi,:));
                highlight(h, ee(:,1), ee(:,2), 'LineWidth', 3)
                ee = cellfun(@(e) find(strcmp(e, d.Nodes.Name), 1, 'first'), d.Edges.EndNodes(d.Edges.aliased,:));
                highlight(h, ee(:,1), ee(:,2), 'EdgeColor', 'r')
            end
            figure(gcf)   % bring to foreground
        end
        
        
        function reload(self)
            % reload all schemas
            self.clearDependencies
            for s=self.packages.values
                reload(feval([s{1} '.getSchema']))
            end
        end
        
        
        function ret = get.isConnected(self)
            ret = ~isempty(self.connId) && 0==mym(self.connId, 'status');
            
            if ~ret && self.inTransaction
                if dj.set('reconnectTimedoutTransaction')
                    warning 'Reconnected after server disconnected during a transaction'
                else
                    error 'Server disconnected during a transaction'
                end
            end
        end
        
        
        function ret = query(self, queryStr, varargin)
            % dj.Connection/query - query(connection, queryStr, varargin) issue an
            % SQL query and return the result if any.
            % The same connection is re-used by all DataJoint objects.
            if ~self.isConnected
                self.connId=mym('open', self.host, self.user, self.password);
                if ~isempty(self.initQuery)
                    self.query(self.initQuery);
                end
            end
            v = varargin;
            if dj.set('bigint_to_double')
                v{end+1} = 'bigint_to_double';
            end
            if nargout>0
                ret=mym(self.connId, queryStr, v{:});
            else
                mym(self.connId, queryStr, v{:});
            end
        end
        
        
        function startTransaction(self)
            self.query('START TRANSACTION WITH CONSISTENT SNAPSHOT')
            self.inTransaction = true;
        end
        
        
        function commitTransaction(self)
            assert(self.inTransaction, 'No transaction to commit')
            self.query('COMMIT')
            self.inTransaction = false;
        end
        
        
        function cancelTransaction(self)
            self.inTransaction = false;
            self.query('ROLLBACK')
        end
        
        
        function close(self)
            if self.isConnected
                fprintf('closing DataJoint connection #%d\n', self.connId)
                mym(self.connId, 'close')
            end
            self.inTransaction = false;
        end
        
        
        function delete(self)
            self.clearDependencies
            self.close
        end
        
        
        function clearDependencies(self, schema)
            if nargin<2
                % remove all if the schema is not specified
                self.foreignKeys = struct([]);
            elseif ~isempty(self.foreignKeys)
                % remove references from the given schema
                % self.referenced.remove
                tableNames = cellfun(@(s) ...
                    sprintf('`%s`.`%s`', schema.dbname, s), ...
                    schema.tableNames.values, 'uni', false);
                self.foreignKeys(ismember({self.foreignKeys.from}, tableNames)) = [];
            end
        end
        
        
        function g = makeGraph(self, list)
            if nargin<=1
                list = union({self.foreignKeys.from}, {self.foreignKeys.ref});
            end
            [~,i] = unique(list);
            list = list(ismember(1:length(list), i));  % remove duplicates
            if isempty(self.foreignKeys)
                ref = [];
                from = [];
            else
                from = arrayfun(@(item) find(strcmp(item.from, list)), self.foreignKeys, 'uni', false);
                ref = arrayfun(@(item) find(strcmp(item.ref, list)), self.foreignKeys, 'uni', false);
                ix = ~cellfun(@isempty, from) & ~cellfun(@isempty, ref);
                if ~isempty(ref)
                    primary = [self.foreignKeys(ix).primary];
                    aliased = [self.foreignKeys(ix).aliased];
                    multi = [self.foreignKeys(ix).multi];
                    ref = [ref{ix}];
                    from = [from{ix}];
                    % for every renamed edge, introduce a new node
                    for m = find(aliased)
                        t = length(list)+1;
                        list{t} = sprintf('%d',t);
                        q = length(ref)+1;
                        ref(q) = ref(m);
                        from(q) = t;
                        ref(m) = t;
                        primary(q) = primary(m);
                        aliased(q) = aliased(m);
                        multi(q) = multi(m);
                    end
                end
            end
            
            g = digraph(ref, from, 1:length(ref), list);
            if g.numedges
                g.Edges.primary = primary(g.Edges.Weight)';
                g.Edges.aliased = aliased(g.Edges.Weight)';
                g.Edges.multi = multi(g.Edges.Weight)';
            end
        end
    end
end