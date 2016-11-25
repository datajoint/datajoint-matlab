classdef Connection < handle
    
    properties(SetAccess = private)
        host
        user
        initQuery    % initializing function or query executed for each new session
        inTransaction = false
        connId       % connection handle
        packages     % maps database names to package names
        
        % dependency lookups by table name
        parents      % maps table names to their parent table names     (primary foreign key)
        referenced   % maps table names to their refenced tables    (non-primary foreign key)
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
                error 'MATLAB version 8.6 or greater is required'
            end
            self.host = host;
            self.user = username;
            self.password = password;
            if nargin>=4
                self.initQuery = initQuery;
            end
            self.parents     = containers.Map('KeyType','char','ValueType','any');
            self.referenced  = containers.Map('KeyType','char','ValueType','any');
            self.packages = containers.Map;
        end
        
        
        function addPackage(self, dbname, package)
            self.packages(dbname) = package;
        end
        
        
        function loadDependencies(self, schema)
            % load dependencies from SHOW CREATE TABLE
            pat = cat(2,...
                'FOREIGN KEY\s+\((?<attrs1>[`\w, ]+)\)\s+',...  % attrs1
                'REFERENCES\s+(?<ref>[^\s]+)\s+',...        % referenced table name
                '\((?<attrs2>[`\w, ]+)\)');
            
            for tabName = schema.headers.keys
                s = self.query(sprintf('SHOW CREATE TABLE `%s`.`%s`', schema.dbname, tabName{1}));
                s = strtrim(regexp(s.('Create Table'){1},'\n','split')');
                s = regexp(s,pat,'names');
                s = [s{:}];
                from = sprintf('`%s`.`%s`',schema.dbname,tabName{1});
                addMember(self.parents, from)
                addMember(self.referenced, from)
                for s=s
                    s.attrs = regexp(s.attrs1,', ', 'split');
                    s.attrs = cellfun(@(s) s(2:end-1), s.attrs, 'uni',false);
                    isPrimary = all(ismember(s.attrs,schema.headers(tabName{1}).primaryKey));
                    if isempty(regexp(s.ref,'`\.`','once'))
                        s.ref = sprintf('`%s`.%s',schema.dbname,s.ref);
                    end
                    if isPrimary
                        addMember(self.parents, from, s.ref)
                    else
                        addMember(self.referenced, from, s.ref)
                    end
                    % add empty entries for all referenced tables too
                    addMember(self.parents, s.ref)
                    addMember(self.referenced, s.ref)
                end
            end
        end
        
        
        function names = children(self, parentTable)
            keys = self.parents.keys;
            names = keys(cellfun(@(key) ismember(parentTable, self.parents(key)), keys));
        end
        
        
        function names = referencing(self, referencedTable)
            keys = self.referenced.keys;
            names = keys(cellfun(@(key) ismember(referencedTable, self.referenced(key)), keys));
        end
        
        
        
        
        function className = tableToClass(self, fullTableName, strict)
            % convert '`dbname`.`table_name`' to 'package.ClassName'
            % If strict (false by default), throw error if the dbname is not found.
            % If not strict and the name is not found, then className=tableName
            
            strict = nargin>=3 && strict;
            s = regexp(fullTableName, '^`(?<dbname>.+)`.`(?<tablename>[#~\w\d]+)`$','names');
            assert(~isempty(s), 'invalid table name %s', fullTableName)
            if self.packages.isKey(s.dbname)
                className = sprintf('%s.%s',self.packages(s.dbname),dj.toCamelCase(s.tablename));
            elseif strict
                error('Unknown package for "%s". Activate its schema first.', fullTableName)
            else
                className = fullTableName;
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
            
            % get additional tables that are connected to ones on the list:
            % up the hierarchy
            lastAdded = list;
            while up || down
                added = [];
                if up
                    temp = cellfun(@(s) ...
                        [self.referenced(s) self.parents(s)], ...
                        lastAdded, 'uni', false);
                    added = setdiff([temp{:}],list);
                    up = up - 1;
                end
                if down
                    temp = cellfun(@(s) ...
                        [self.referencing(s) self.children(s)], ...
                        lastAdded, 'uni', false);
                    added = union(added,setdiff([temp{:}],list));
                    down = down - 1;
                end
                list = union(list,added);
                lastAdded = added;
            end
            
            % determine tiers
            re = cellfun(@(s) sprintf('`.+`\\.`%s[a-z].*`',s), dj.Schema.tierPrefixes, 'uni', false);
            tiers = dj.Schema.allowedTiers(cellfun(@(l) find(~cellfun(@isempty, regexp(l, re))),list));
            % exclude job tables
            j = ~strcmp(tiers,'job');
            list = list(j);
            tiers = tiers(j);
            
            C = self.makeDependencyMatrix(list);
            if sum(C(:))==0
                disp 'No dependencies found. Nothing to plot'
                return
            end
            d = digraph(C, cellfun(@self.tableToClass, list, 'uni', false));
            d.Nodes.tier = tiers';
            colormap(0.3+0.7*[
                0.0 0.5 0.0
                0.3 0.3 0.3
                0.0 0.0 1.0
                1.0 0.0 0.0
                1.0 1.0 1.0
                ]);
            node_color = struct(...
                'manual',   1, ...
                'lookup',   2, ...
                'imported', 3, ...
                'computed', 4, ...
                'job',      5);
            marker = struct(...
                'manual',   'square', ...
                'lookup',   'hexagram', ...
                'imported', 'o', ...
                'computed', 'pentagram', ...
                'job',      5);
            d.Nodes.color = cellfun(@(x) node_color.(x), tiers)';
            d.Nodes.marker = cellfun(@(x) marker.(x), tiers, 'uni', false)';
            h = d.plot('layout', 'layered', 'NodeLabel', []);
            h.NodeCData = d.Nodes.color;
            caxis([0.5 5.5])
            h.MarkerSize = 16;
            h.Marker = d.Nodes.marker;
            axis off
            h.LineWidth = 2;
            line_styles = {'-', ':'};
            h.LineStyle = line_styles(d.Edges.Weight);
            for i=1:d.numnodes
                text(h.XData(i)+0.1,h.YData(i), d.Nodes.Name(i), ...
                    'fontsize', 12, 'rotation', -16); 
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
                self.parents.remove(self.parents.keys);
                self.referenced.remove(self.referenced.keys);
            else
                % remove references from the given schema
                % self.referenced.remove
                tableNames = cellfun(@(s) ...
                    sprintf('`%s`.`%s`', schema.dbname, s), ...
                    schema.tableNames.values, 'uni', false);
                self.parents.remove(intersect(self.parents.keys,tableNames));
                self.referenced.remove(intersect(self.referenced.keys,tableNames));
            end
        end
        
        
        function C = makeDependencyMatrix(self, list)
            n = length(list);
            C = sparse([],[],[],n,n);
            for i=1:n
                j = cellfun(@(c) find(strcmp(c,list))', self.children(list{i}), 'uni', false);
                j(cellfun(@isempty, j)) = [];
                C(i,cat(1,j{:}))=1; %#ok<SPRIX>
                j = cellfun(@(c) find(strcmp(c,list))', self.referencing(list{i}), 'uni', false);
                C(i,cat(1,j{:}))=2; %#ok<SPRIX>
            end
        end
    end
end



function addMember(map,key,value)
if ~map.isKey(key)
    map(key) = {};
end
if  nargin>=3
    map(key) = [map(key) {value}]; %#ok<NASGU>
end
end
