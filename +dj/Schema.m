% manages information about database tables and their dependencies
% Complete documentation is available at <a href=http://code.google.com/p/datajoint/wiki/TableOfContents>Datajoint wiki</a>
% See also dj.Table, dj.Relvar

classdef Schema < handle
    
    properties(SetAccess = private)
        package % the package (directory starting with a +) that stores schema classes, must be on path
        host
        user
        dbname  % database (schema) name
        tables  % full list of tables
        classNames % classes corresponding to tables
        fields  % full list of all table fields
        dependencies  % sparse adjacency matrix with 1=parent/child and 2=non-primary key reference
        jobReservations    % a dj.Relvar of the job reservation table
    end
    
    properties(Access = private)
        password
        tableLevels   % levels in dependency hiararchy
        connection
        jobKey        % currently checked out job
    end
    
    methods
        
        function self = Schema(package, host, dbname, user, password,  port)
            assert(nargin>=5, 'missing database credentials');
            if nargin<6
                self.host = host;
            else
                self.host = sprintf('%s:%d', host, port);
            end
            self.package = package;
            self.user = user;
            self.password = password;
            self.dbname = dbname;
            self.reload
        end
        
        
        
        function erd(self, subset)
            % plot the Entity Relationship Diagram of the entire schema
            % INPUTS:
            %    subset -- indices schema.table to include in the diagram.
            
            if nargin==1
                subset = 1:length(self.tableLevels);
            end
            levels = -self.tableLevels(subset);
            C = self.dependencies(subset,subset);  % connectivity matrix
            
            yi = levels;
            xi = zeros(size(yi));
            
            % optimize graph appearance by minimizing disctances.^2 to connected nodes
            % while maximizing distances to nodes on the same level.
            fprintf 'optimizing layout...'
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
            plot(xi, yi, 'o', 'MarkerSize', 10);
            hold on;
            c = hsv(16);
            % plot edges
            for i=1:size(C,1)
                ci = round((yi(i)-min(yi))/(max(yi)-min(yi))*15)+1;
                cc = c(ci,:)*0.3+0.4;
                for j=1:size(C,2)
                    switch C(i,j)
                        case 1
                            connectNodes(xi([i j]), yi([i j]), '-', cc);
                        case 2
                            connectNodes(xi([i j]), yi([i j]), '--', cc);
                    end
                    hold on
                end
            end
            
            % annotate nodes
            for i=1:length(subset)
                switch self.tables(subset(i)).tier
                    case 'manual'
                        c = [0 0.6 0];
                    case 'lookup'
                        c = [0.3 0.4 0.3];
                    case 'imported'
                        c = [0 0 1];
                    case 'computed'
                        c = [0.5 0.0 0];
                end
                text(xi(i), yi(i), [dj.utils.camelCase(self.tables(subset(i)).name) '  '], ...
                    'HorizontalAlignment', 'right', ...
                    'Color', c, 'FontSize', 12);
                hold on;
            end
            
            xlim([min(xi)-0.5 max(xi)+0.5]);
            ylim([min(yi)-0.5 max(yi)+0.5]);
            hold off
            axis off
            disp done
            
            
            function connectNodes(x, y, lineStyle, color)
                assert(length(x)==2 && length(y)==2)
                plot(x, y, 'k.')
                t = 0:0.05:1;
                x = x(1) + (x(2)-x(1)).*(1-cos(t*pi))/2;
                y = y(1) + (y(2)-y(1))*t;
                plot(x, y, lineStyle, 'Color', color)
            end
        end
        
        
        
        function backup(self, backupDir, tiers)
            % Saves tables into .mat files
            % Each tables must be small enough to be loaded into memory.
            % By default, only lookup and manual tables are saved.
            if nargin<3
                tiers = {'lookup','manual'};
            end
            assert(all(ismember(tiers, dj.utils.allowedTiers)))
            backupDir = fullfile(backupDir, self.dbname);
            if ~exist(backupDir, 'dir')
                assert(mkdir(backupDir), ...
                    'Could not create directory %s', backupDir)
            end
            backupDir = fullfile(backupDir, datestr(now,'yyyy-mm-dd'));
            if ~exist(backupDir,'dir')
                assert(mkdir(backupDir), ...
                    'Could not create directory %s', backupDir)
            end
            ix = find(ismember({self.tables.tier}, tiers));
            % save in hiearchical order
            [~,order] = sort(self.tableLevels(ix));
            ix = ix(order);
            for iTable = ix(:)'
                contents = self.query(sprintf('SELECT * FROM `%s`.`%s`', ...
                    self.dbname, self.tables(iTable).name));
                contents = dj.utils.structure2array(contents);
                filename = fullfile(backupDir, ...
                    regexprep(self.classNames{iTable}, '^.*\.', ''));
                fprintf('Saving %s to %s ...', self.classNames{iTable}, filename)
                save(filename, 'contents')
                fprintf 'done\n'
            end
        end
        
        
        
        function delete(self)
            % deletes the schme
            % unfortunately mym leaves open invisible connections after
            % clear classes.  The connections are only cleared upon exiting
            % matlab.
            disp 'closing DataJoint connections'
            mym closeall
            self.delete@handle
        end
        
        
        
        function reload(self)
            % load schema information into memory: table names and table
            % dependencies.
            
            % load table information
            fprintf('loading table definitions from %s/%s... ', self.host, self.dbname)
            tic
            self.tables = self.query(sprintf([...
                'SELECT table_name AS name, table_comment AS comment ', ...
                'FROM information_schema.tables WHERE table_schema="%s"'], ...
                self.dbname));
            
            % determine table tier (see dj.Table)
            re = [cellfun(@(x) ...
                sprintf('^%s[a-z]\\w+$',x), dj.utils.tierPrefixes, ...
                'UniformOutput', false) ...
                {'.*'}];  % regular expressions to determine table tier
            tierIdx = cellfun(@(x) ...
                find(~cellfun(@isempty, regexp(x, re, 'once')),1,'first'), ...
                self.tables.name);
            self.tables.tier = dj.utils.allowedTiers(min(tierIdx,end))';
            
            % exclude tables that do not match the naming conventions
            validTables = tierIdx < length(re);  % matched table name pattern
            self.tables.comment = cellfun(@(x) strtok(x,'$'), self.tables.comment, 'UniformOutput', false);  % strip MySQL's comment
            self.tables = dj.utils.structure2array(self.tables);
            self.tables = self.tables(validTables);
            self.classNames = cellfun(@(x) sprintf('%s.%s', self.package, dj.utils.camelCase(x)), {self.tables.name}, 'UniformOutput', false);
            
            % read field information
            if ~isempty(self.tables)
                fprintf('%.3g s\nloading field information... ', toc), tic
                self.fields = query(self, sprintf([...
                    'SELECT table_name AS `table`, column_name as `name`,'...
                    '(column_key="PRI") AS `iskey`,column_type as `type`,'...
                    '(is_nullable="YES") AS isnullable, column_comment as `comment`,'...
                    'if(is_nullable="YES","NULL",ifnull(CAST(column_default AS CHAR),"<<<none>>>"))',...
                    ' AS `default` FROM information_schema.columns '...
                    'WHERE table_schema="%s"'],...
                    self.dbname));
                self.fields.isnullable = logical(self.fields.isnullable);
                self.fields.iskey = logical(self.fields.iskey);
                self.fields.isNumeric = ~cellfun(@(x) isempty(regexp(char(x'), '^((tiny|small|medium|big)?int|decimal|double|float)', 'once')), self.fields.type);
                self.fields.isString = ~cellfun(@(x) isempty(regexp(char(x'), '^((var)?char|enum|date|timestamp)','once')), self.fields.type);
                self.fields.isBlob = ~cellfun(@(x) isempty(regexp(char(x'), '^(tiny|medium|long)?blob', 'once')), self.fields.type);
                % strip field lengths off integer types
                self.fields.type = cellfun(@(x) regexprep(char(x'), '((tiny|long|small|)int)\(\d+\)','$1'), self.fields.type, 'UniformOutput', false);
                self.fields = dj.utils.structure2array(self.fields);
                self.fields = self.fields(ismember({self.fields.table}, {self.tables.name}));
                validFields = [self.fields.isNumeric] | [self.fields.isString] | [self.fields.isBlob];
                if ~all(validFields)
                    ix = find(~validFields, 1, 'first');
                    error('unsupported field type "%s" in %s.%s', ...
                        self.fields(ix).type, self.fields.table(ix), self.fields.name(ix));
                end
                
                % load table dependencies
                fprintf('%.3g s\nloading table dependencies... ', toc), tic
                tableList = sprintf(',"%s"',self.tables.name);
                foreignKeys = dj.utils.structure2array(self.query(sprintf([...
                    'SELECT table_name as `from`, referenced_table_name as `to`,'...
                    '  min((table_schema, table_name,column_name) in'...
                    '    (SELECT table_schema, table_name, column_name'...
                    '    FROM information_schema.columns WHERE column_key="PRI")) as parental '...
                    'FROM information_schema.key_column_usage '...
                    'WHERE table_schema="%s" and referenced_table_schema="%s" '...
                    'AND table_name in (%s) and referenced_table_name in (%s) '...
                    'GROUP BY table_name, referenced_table_name'],...
                    self.dbname, self.dbname, tableList(2:end), tableList(2:end))));
                
                ixFrom = cellfun(@(x) find(strcmp(x, {self.tables.name})), {foreignKeys.from});
                ixTo = cellfun(@(x) find(strcmp(x, {self.tables.name})), {foreignKeys.to});
                nTables = length(self.tables);
                self.dependencies = sparse(ixFrom, ixTo, 2-[foreignKeys.parental], nTables, nTables);
                
                % determine tables' hierarchical order
                K = self.dependencies;
                ik = 1:length(self.tables);
                levels = nan(size(ik));
                level = 0;
                while ~isempty(K)
                    orphans = sum(K,2)==0;
                    levels(ik(orphans)) = level;
                    level = level + 1;
                    ik = ik(~orphans);
                    K = K(~orphans,~orphans);
                end
                
                % lower level if possible
                for j=1:length(self.tables)
                    ix = find(self.dependencies(:,j));
                    if ~isempty(ix)
                        levels(j)=min(levels(ix)-1);
                    end
                end
                fprintf('%.3g s\n', toc)
                
                self.tableLevels = levels;
            end
        end
        
        
        
        function startTransaction(self)
            self.query('START TRANSACTION WITH CONSISTENT SNAPSHOT')
        end
        
        
        
        function commitTransaction(self)
            self.query('COMMIT')
        end
        
        
        
        function cancelTransaction(self)
            self.query('ROLLBACK')
        end
        
        
        
        function ret = query(self, queryStr, varargin)
            % dj.Schema/query - query(dbname, queryStr, varargin) issue an
            % SQL query and return the result if any.
            % Reuses the same connection, which limits connections to one
            % database server at a time, but multiple schemas are okay.
            %}
            if isempty(self.connection) || 0<mym(self.connection, 'status')
                self.connection=mym('open', self.host, self.user, self.password);
            end
            if nargout>0
                ret=mym(self.connection, queryStr, varargin{:});
            else
                mym(self.connection, queryStr, varargin{:});
            end
        end
        
        
        
        function makeClass(self, className, tier, isAuto)
            % create a base relvar class for the new className in schema
            % directory.
            %
            % Example:
            %    s = v2p.getSchema;
            %    s.makeClass('CellOriRegression', 'computed', false)
            
            if nargin<3
                tier = 'computed';
            end
            assert(ismember(tier, dj.utils.allowedTiers), ...
                'tier must be one of dj.utils.allowedTiers')
            isAuto = ismember(tier, {'computed','imported'}) && ...
                (nargin<4 || isAuto);
            
            filename = fileparts(which(sprintf('%s.getSchema', self.package)));
            assert(~isempty(filename), 'could not find +%s/getSchema.m', self.package);
            filename = fullfile(filename, [className '.m']);
            assert( ~exist(filename,'file'), '%s already exists', filename)
            
            f = fopen(filename,'wt');
            assert(-1 ~= f, 'Could not open %s', filename)
            
            % table declaration
            fprintf(f, '%% %s.%s - my newest table\n', self.package, className);
            fprintf(f, '%% I will explain what my table does here \n\n');
            fprintf(f, '%%{\n');
            fprintf(f, '%s.%s (%s) # my newest table\n\n', self.package, className, tier);
            fprintf(f, '-----\n\n');
            fprintf(f, '%%}\n\n');
            
            % class definition
            fprintf(f, 'classdef %s < dj.Relvar', className);
            if isAuto
                fprintf(f, ' & dj.AutoPopulate');
            end
            
            % properties
            fprintf(f, '\n\n\tproperties(Constant)\n');
            fprintf(f, '\t\ttable = dj.Table(''%s.%s'')\n', self.package, className);
            if isAuto
                fprintf(f, '\t\tpopRel = \n');
            end
            fprintf(f, '\tend\n');
            
            % constructor
            fprintf(f, '\n\tmethods\n');
            fprintf(f, '\t\tfunction self = %s(varargin)\n', className);
            fprintf(f, '\t\t\tself.restrict(varargin)\n');
            fprintf(f, '\t\tend\n');
            
            % metod makeTuples
            if isAuto
                fprintf(f, '\n\t\tfunction makeTuples(self, key)\n');
                fprintf(f, '\t\t\t ... compute new fields for key ...\n');
                fprintf(f, '\t\t\tself.insert(key)\n');
                fprintf(f, '\t\tend\n');
            end
            fprintf(f, '\tend\n');
            fprintf(f, 'end\n');
            fclose(f);
            edit(filename)
        end
        
        
        
        
        function manageJobs(self, jobReservations)
            if nargin == 1
                self.jobReservations = [];
            else
                assert(isa(jobReservations, 'dj.Relvar'));
                self.jobReservations = jobReservations;
            end
            self.jobKey = [];
        end
        
        
        
        function success = setJobStatus(self, key, status, errMsg, errStack)
            % dj.Schema/setJobStatus - manage jobs
            % This processed is used by dj.AutoPopulate/populate to reserve
            % jobs for distributed processing. Jobs are managed only when a
            % job manager is specified using dj.Schema/setJobManager
            
            % if no job manager, do nothing
            success = isempty(self.jobReservations);
            
            if ~success
                switch status
                    case {'completed','error'}
                        % check that this is the matching job
                        if ~isempty(self.jobKey)
                            assert(~isempty(dj.utils.structJoin(key, self.jobKey)),...
                                'job key mismatch ')
                            self.jobKey = [];
                        end
                        key = dj.utils.structPro(key, self.jobReservations.primaryKey);
                        key.job_status = status;
                        if nargin>3
                            key.error_message = errMsg;
                        end
                        if nargin>4
                            key.error_stack = errStack;
                        end
                        self.jobReservations.insert(key, 'REPLACE')
                        success = true;
                        
                    case 'reserved'
                        % check if the job is already ours
                        success = ~isempty(self.jobKey) && ...
                            ~isempty(dj.utils.structJoin(key, self.jobKey));
                        
                        if ~success
                            % mark previous job completed
                            if ~isempty(self.jobKey)
                                self.jobKey.job_status = 'completed';
                                self.jobReservations.insert(...
                                    self.jobKey, 'REPLACE');
                                self.jobKey = [];
                            end
                            
                            % create the new job key
                            for f = self.jobReservations.primaryKey
                                try
                                    self.jobKey.(f{1}) = key.(f{1});
                                catch e
                                    error 'Incomplete job key: use a more general job reservation table.'
                                end
                            end
                            
                            % check if the job is available
                            try
                                self.jobReservations.insert(...
                                    setfield(self.jobKey,'job_status',status))  %#ok
                                success = true;
                                disp 'RESERVED JOB:'
                                disp(self.jobKey)
                            catch %#ok
                                % reservation failed due to a duplicate, move on
                                % to the next job
                                self.jobKey = [];
                            end
                        end
                    otherwise
                        error 'invalid job status'
                end
            end
        end
    end
end