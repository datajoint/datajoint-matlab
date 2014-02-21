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
                error('Outdated version of mYm.  Please upgrade to version 2.6 or later')
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
                    assert(isequal(s.attrs1,s.attrs2),...
                        'Foreign keys must link identically named attributes')
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
            
            % load all schemas before plotting
            for s=self.packages.values
                reload(feval([s{1} '.getSchema']),false)
            end
            
            % get additional tables that are connected to ones on the list:
            % up the hierarchy
            lastAdded = list;
            while up || down
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
            j = ~strcmp(tiers,'job');
            list = list(j);  % exclude jobs
            tiers = tiers(j);
            
            
            % construct the dependency matrix C(to,from)
            n = length(list);
            C = sparse([],[],[],n,n);
            for i=1:n
                j = cellfun(@(c) find(strcmp(c,list)), self.children(list{i}), 'uni', false);
                C(i,[j{:}])=1; %#ok<SPRIX>
                j = cellfun(@(c) find(strcmp(c,list)), self.referencing(list{i}), 'uni', false);
                C(i,[j{:}])=2; %#ok<SPRIX>
            end
            
            if sum(C(:))==0
                disp 'No dependencies found. Nothing to plot'
                return
            end
            
            % compute levels in hierarchy
            level = zeros(size(list));
            updated = true;
            while updated
                updated = false;
                for i=1:n
                    j = find(C(i,:));
                    if ~isempty(j)
                        newLevel = max(level(j))+1;
                        if level(i)~=newLevel
                            updated = true;
                            level(i) = newLevel;
                        end
                    end
                end
            end
            % tighten up levels
            updated = true;
            while updated
                updated = false;
                for i=1:n
                    j = find(C(:,i));
                    if ~isempty(j)
                        newLevel = min(level(j))-1;
                        if newLevel ~= level(i)
                            updated = true;
                            level(i) = newLevel;
                        end
                    end
                end
            end
            
            
            % convert to 'package.ClassName'
            names = cellfun(@self.tableToClass,list,'uni',false);
            
            % plot
            
            yi = level;
            xi = zeros(size(yi));
            
            % optimize graph appearance by minimizing disctances.^2 to connected nodes
            % while maximizing distances to nodes on the same level.
            j1 = cell(1,length(xi));
            j2 = cell(1,length(xi));
            for i=1:length(xi)
                j1{i} = setdiff(find(yi==yi(i)),i);
                j2{i} = [find(C(i,:)) find(C(:,i)')];
            end
            niter=5e4;
            T0=5; % initial temperature
            cr=6/niter; % cooling rate
            L = inf(size(xi));
            for iter=1:niter
                i = ceil(rand*length(xi));  % pick a random node
                
                % Compute the cost function Lnew of the increasing xi(i) by dx
                dx = 5*randn*exp(-cr*iter/2);  % steps don't cools as fast as the annealing schedule
                xx=xi(i)+dx;
                Lnew = abs(xx)/10 + sum(abs(xx-xi(j2{i}))); % punish for remoteness from center and from connected nodes
                if ~isempty(j1{i})
                    Lnew= Lnew+sum(1./(0.01+(xx-xi(j1{i})).^2));  % punish for propximity to same-level nodes
                end
                
                if L(i) > Lnew + T0*randn*exp(-cr*iter) % simulated annealing
                    xi(i)=xi(i)+dx;
                    L(i) = Lnew;
                end
            end
            yi = yi+cos(xi*pi+yi*pi)*0.2;  % stagger y positions at each level
            
            
            % plot nodes
            plot(xi, yi, 'ko', 'MarkerSize', 10);
            hold on;
            % plot edges
            for i=1:size(C,1)
                for j=1:size(C,2)
                    switch C(i,j)
                        case 1
                            connectNodes(xi([i j]), yi([i j]), 'k-')
                        case 2
                            connectNodes(xi([i j]), yi([i j]), 'k--')
                    end
                    hold on
                end
            end
            
            % annotate nodes
            fontColor = struct(...
                'manual',   [0.0 0.6 0.0], ...
                'lookup',   [0.3 0.4 0.3], ...
                'imported', [0.0 0.0 1.0], ...
                'computed', [0.5 0.0 0.0], ...
                'job',      [1 1 1]);
            
            for i=1:length(level)
                name = names{i};
                if exist(name,'class')
                    rel = feval(name);
                    assert(isa(rel, 'dj.Relvar'))
                    if rel.isSubtable
                        name = [name '*'];  %#ok:AGROW
                    end
                end
                edgeColor = 'none';
                fontSize = 11;
                text(xi(i), yi(i), [name '  '], ...
                    'HorizontalAlignment', 'right', 'interpreter', 'none', ...
                    'Color', fontColor.(tiers{i}), 'FontSize', fontSize, 'edgeColor', edgeColor);
                hold on;
            end
            
            xlim([min(xi)-0.5 max(xi)+0.5]);
            ylim([min(yi)-0.5 max(yi)+0.5]);
            hold off
            axis off
            
            function connectNodes(x, y, lineStyle)
                assert(length(x)==2 && length(y)==2)
                plot(x, y, 'k.')
                t = 0:0.05:1;
                x = x(1) + (x(2)-x(1)).*(1-cos(t*pi))/2;
                y = y(1) + (y(2)-y(1))*t;
                plot(x, y, lineStyle)
            end
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
            if nargout>0
                ret=mym(self.connId, queryStr, varargin{:});
            else
                mym(self.connId, queryStr, varargin{:});
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
