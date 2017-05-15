% dj.internal.AutoPopulate is an abstract UserRelation class that
% automatically populate its table.
%
% Derived classes must define the callback function makeTuples(self, key),
% which computes new tuples for the given key and inserts them into the table as
% self.insert(tuple).
%
% The constant property 'keySource' must be defined in the derived class.
% dj.internal.AutoPopulate/populate uses self.keySource to generate the list of unpopulated keys
% for which self.makeTuples() will be invoked. Thus keySource determines the scope
% and granularity of makeTuples calls.
%
% Once self.makeTuples and self.keySource are defined, the user may
% invoke methods poopulate or parpopulate to automatically populate the table.
%
% The method parpopulate works similarly to populate but it uses the job reservation
% table <package>.Jobs to enable execution by multiple processes in parallel.
%
% The job reservation table <package>.Jobs and its class are created automatically
% upon the first invocation of parpopulate(). You may query the job reservation
% to monitor the progression of execution.
% While the job is executing, the job status is set to "reserved". When the
% job is completed, the entry is removed. When the job ends in error, the
% status is set to "error" and the error stack is saved.

classdef AutoPopulate < dj.internal.UserRelation
    
    properties(Dependent)
        jobs  % the jobs table
    end
    
    properties(Access=protected)
        keySource_
        useReservations
        executionEngine
        jobs_     % used for self.jobs
        timedOut  % list of timedout transactions
        timeoutAttempt
    end
    
    properties(Constant, Access=protected)
        timeoutMessage = 'Lock wait timeout exceeded'
        maxTimeouts = 3
    end
    
    
    methods(Abstract,Access=protected)
        makeTuples(self, key)
        % makeTuples(self, key) must be defined by each automatically
        % populated relvar. makeTuples copies key as tuple, adds computed
        % fields to tuple and inserts tuple as self.insert(tuple)
    end
    
    methods
        
        
        function source = getKeySource(self)
            % construct key source for auto-population of imported and
            % computed tables.
            % By default the key source is the join of the primary parents.
            % Users can customize the key source by defining the optional
            % keySource property.
            
            if ~isempty(self.keySource_)
                source = self.keySource_;
            else
                if isprop(self, 'popRel')
                    source = self.popRel;
                elseif isprop(self, 'keySource')
                    source = self.keySource;
                else
                    % the default key source is the join of the parents
                    parents = self.parents(true);
                    assert(~isempty(parents), ...
                        'AutoPopulate table %s must have primary dependencies or an explicit keySource property', class(self))
                    r = @(ix) dj.Relvar(self.schema.conn.tableToClass(parents{ix}));
                    source = r(1);
                    for i=2:length(parents)
                        source = source * r(i);
                    end
                end
                self.keySource_ = source;
            end
        end
        
        
        function varargout = populate(self, varargin)
            % [failedKeys, errors] = populate(baseRelvar [, restrictors...])
            % populates a table based on the contents self.getKeySource
            %
            % The method self.getKeySource yields the relation that provides
            % the keys for which self must be populated.
            %
            % self.populate will call self.makeTuples(key) for every
            % key in the key source that does not already have matching tuples
            % in self.
            %
            % Additional input arguments contain restriction conditions
            % applied to the key source.  Therefore, all keys to be populated
            % are obtained as fetch((self.getKeySource - self) & varargin).
            %
            % Without any output arguments, populate rethrows errors
            % that occur in makeTuples. However, if output arguments are
            % requested, errors are suppressed and accumuluated into output
            % arguments.
            %
            % EXAMPLES:
            %   populate(tp.OriMaps)   % populate all tp.OriMaps
            %   populate(tp.OriMaps, 'mouse_id=12')    % populate OriMaps for mouse 12
            %   [failedKeys, errs] = populate(tp.OriMaps);  % skip errors and return their list
            %
            % See also dj.internal.AutoPopulate/parpopulate
            
            if ~dj.set('populateAncestors')
                rels = {self};
            else
                % get all ancestors to be populated before self
                assert(nargout==0, ...
                    'parpopulate cannot return output when populateAncestors is true')
                rels = cellfun(@feval, self.ancestors, 'uni', false);
                rels = rels(cellfun(@(x) isa(x,'dj.internal.AutoPopulate'), rels));
            end
            
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            
            for i=1:length(rels)
                rels{i}.useReservations = false;
                rels{i}.populateSanityChecks
                rels{i}.executionEngine = @(key, fun, args) fun(args{:});
                [varargout{1:nargout}] = rels{i}.populate_(varargin{:});
            end
        end
        
        
        function parpopulate(self, varargin)
            % dj.internal.AutoPopulate/parpopulate works identically to dj.internal.AutoPopulate/populate
            % except that it uses a job reservation mechanism to enable multiple
            % processes to populate the same table in parallel without collision.
            %
            % To enable parpopulate, create the job reservation table
            % <package>.Jobs which must have the following declaration:
            %
            %   <package>.Jobs (job) # the job reservation table
            %
            %   table_name      : varchar(255)          # className of the table
            %   key_hash        : char(32)              # key hash
            %   ---
            %   status            : enum('reserved','error','ignore')# if tuple is missing, the job is available
            %   key=null          : blob                  # structure containing the key
            %   error_message=""  : varchar(1023)         # error message returned if failed
            %   error_stack=null  : blob                  # error stack if failed
            %   host=""           : varchar(255)          # system hostname
            %   pid=0             : int unsigned          # system process id
            %   timestamp=CURRENT_TIMESTAMP : timestamp    # automatic timestamp
            %
            % A job is considered to be available when <package>.Jobs contains
            % no matching entry.
            %
            % For each makeTuples call, parpopulate sets the job status to
            % "reserved".  When the job is completed, the record is
            % removed. If the job results in error, the job record is left
            % in place with the status set to "error" and the error message
            % and error stacks saved. Consequently, jobs that ended in
            % error during the last execution will not be attempted again
            % until you delete the job tuples from package.Jobs.
            %
            % The primary key of the jobs table comprises the name of the
            % class and a 32-character hash of the primary key. However, the
            % key is saved in a separate field for errors for debugging
            % purposes.
            %
            % See also dj.internal.AutoPopulate/populate
            
            if ~dj.set('populateAncestors')
                rels = {self};
            else
                % get all ancestors to be populated before self
                rels = cellfun(@feval, self.ancestors, 'uni', false);
                rels = rels(cellfun(@(x) isa(x,'dj.internal.AutoPopulate'), rels));
            end
            
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            
            for i=1:length(rels)
                rels{i}.useReservations = true;
                rels{i}.populateSanityChecks
                rels{i}.executionEngine = @(key, fun, args) fun(args{:});
                rels{i}.populate_(varargin{:});
            end
        end
        
        
        function taskCore(self, key)
            % The work unit that is submitted to the cluster
            % or executed locally
            
            function cleanup(self, key)
                self.schema.conn.cancelTransaction
                if self.hasJobs
                    tuple = fetch(self.jobs & self.makeJobKey(key), 'status');
                    if ~isempty(tuple) && strcmp(tuple.status, 'reserved')
                        self.setJobStatus(key, 'error', 'Populate interrupted', []);
                    end
                end
            end
            % this is guaranteed to be executed when the function is
            % terminated even if by KeyboardInterrupt (CTRL-C)
            % When used with onCleanup,  the function itself cannot contain upvalues
            cleanupObject = onCleanup(@() cleanup(self, key));
            
            self.schema.conn.startTransaction()
            try
                self.makeTuples(key)
                self.schema.conn.commitTransaction
                self.setJobStatus(key, 'completed');
            catch err
                self.schema.conn.cancelTransaction
                if strncmpi(err.message, self.timeoutMessage, length(self.timeoutMessage)) && ...
                        self.timeoutAttempt<=self.maxTimeouts
                    fprintf 'Transaction timed out. Will attempt again later.\n'
                    self.setJobStatus(key, 'completed');
                    self.timedOut = [self.timedOut; key];
                else
                    self.setJobStatus(key, 'error', err.message, err.stack);
                    rethrow(err)   % Make error visible to DCT / caller
                end
            end
        end
        
        
        function yes = hasJobs(self)
            yes = ~isempty(self.jobs_);
        end
        
        function jobs = get.jobs(self)
            % Return the jobs table associated with this current schema.
            % Create the jobs table if it does not yet exist.
            if ~self.hasJobs
                jobClassName = [self.schema.package '.Jobs'];
                if ~exist(jobClassName,'class')
                    self.createJobTable
                    rehash path
                end
                self.jobs_ = feval(jobClassName);
            end
            jobs = self.jobs_;
        end
        
        
        function varargout = progress(self, varargin)
            % show progress (fraction populated)
            if ~isempty(self.restrictions)
                throwAsCaller(MException('DataJoint:invalidInput', ...
                    'Cannot populate a restricted relation. Correct syntax: progress(rel, restriction)'))
            end
            
            remaining = count((self.getKeySource & varargin) - self);
            if nargout
                % return remaning items if asked
                varargout{1} = remaining;
            else
                fprintf('%s %30s:  ', datestr(now,'yyyy-mm-dd HH:MM:SS'), self.className)
                total = count(self.getKeySource & varargin);
                if ~total
                    disp 'Nothing to populate'
                else
                    fprintf('%6.2f%% complete (%d of %d)\n', ...
                        100-100*double(remaining)/double(total), total-remaining, total)
                end
            end
        end
    end
    
    
    methods(Access = protected)
        function [failedKeys, errors] = populate_(self, varargin)
            % common functionality to all populate method
            
            if nargout
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            % create tables of all parts in a master-part relationship to
            % avoid implicit commits.
            for part = self.getParts
                part{1}.create
            end
            
            popRestricts = varargin;  % restrictions on key source
            restricts = self.restrictions;  % restricts on self
            if isempty(restricts)
                unpopulated = fetch((self.getKeySource & popRestricts) - self.proj());
            else
                assert(numel(restricts)==1, 'only one restriction is allowed in populated relations')
                restricts = restricts{1};
                if isa(restricts, 'dj.GeneralRelvar')
                    restricts = fetch(restricts);
                end
                assert(isstruct(restricts), ...
                    'populated relvars can be restricted only by other relations, structures, or structure arrays')
                % the rule for populating restricted relations:
                unpopulated = dj.struct.join(restricts, fetch((self.getKeySource & popRestricts & restricts) - (self & restricts)));
            end
            
            % restrict the key source to unpopulated tuples
            if isempty(unpopulated)
                fprintf('%s: Nothing to populate\n', self.className)
            else
                fprintf('\n**%s: Found %d unpopulated keys\n\n', self.className, length(unpopulated))
                
                self.timeoutAttempt = 1;
                while ~isempty(unpopulated)
                    self.timedOut = [];
                    for key = unpopulated'
                        if self.setJobStatus(key, 'reserved')
                            if exists(self & key)
                                % already populated
                                self.setJobStatus(key, 'completed');
                            else
                                fprintf('Populating %s for:\n', self.className)
                                disp(key)
                                try
                                    % Perform or schedule computation
                                    self.executionEngine(key, @taskCore, {self, key})
                                catch err
                                    if ~nargout && ~self.useReservations
                                        rethrow(err)
                                    end
                                    % suppress error if it is handled by other means
                                    fprintf('\n** Error while executing %s.makeTuples:\n', class(self))
                                    fprintf('%s: line %d\n', err.stack(1).file, err.stack(1).line)
                                    fprintf('"%s"\n\n',err.message)
                                    if nargout
                                        failedKeys = [failedKeys; key]; %#ok<AGROW>
                                        errors = [errors; err];         %#ok<AGROW>
                                    end
                                end
                            end
                        end
                    end
                    unpopulated = self.timedOut;
                    self.timeoutAttempt = self.timeoutAttempt + 1;
                end
            end
        end
        
        
        function jobKey = makeJobKey(self, key)
            hash = dj.internal.hash(key);
            jobKey = struct('table_name', self.className, 'key_hash', hash(1:32));
        end
        
        
        function success = setJobStatus(self, key, status, errMsg, errStack)
            % dj.internal.AutoPopulate/setJobStatus - update job process for parallel execution.
            success = ~self.useReservations;
            if ~success
                jobKey = self.makeJobKey(key);
                switch status
                    case 'completed'
                        delQuick(self.jobs & jobKey)
                    case 'error'
                        jobKey.status = status;
                        jobKey.error_message = errMsg;
                        jobKey.error_stack = errStack;
                        self.jobs.insert(addJobInfo(jobKey),'REPLACE')
                    case 'reserved'
                        success = ~exists(self.jobs & jobKey);
                        if success
                            jobKey.status = status;
                            try
                                self.jobs.insert(addJobInfo(jobKey))
                            catch %#ok<CTCH>
                                success = false;
                            end
                        end
                        if ~success && dj.set('verbose')
                            fprintf('** %s: skipping already reserved\n', self.className)
                            disp(key)
                        end
                end
            end
            
            
            function jobKey = addJobInfo(jobKey)
                if all(ismember({'host','pid'},self.jobs.header.names))
                    try
                        host = char(getHostName(java.net.InetAddress.getLocalHost));
                    catch
                        [~,host] = system('hostname');
                    end
                    jobKey.host = strtrim(host);
                    jobKey.pid = feature('getpid');
                end
                if ismember('error_key', self.jobs.header.names)
                    % for backward compatibility with versions prior to 2.6.3
                    jobKey.error_key = key;
                end
                if ismember('key', self.jobs.header.names)
                    jobKey.key = key;
                end
                
            end
        end
        
        
        function createJobTable(self)
            % Create the Jobs class if it does not yet exist
            schemaPath = which([self.schema.package '.getSchema']);
            assert(~isempty(schemaPath), 'missing function %s.getSchema', self.schema.package)
            path = fullfile(fileparts(schemaPath), 'Jobs.m');
            f = fopen(path,'w');
            fprintf(f, '%%{\n');
            fprintf(f, '# the job reservation table for +%s\n', self.schema.package);
            fprintf(f, 'table_name : varchar(255) # className of the table\n');
            fprintf(f, 'key_hash   : char(32)     # key hash\n');
            fprintf(f, '-----\n');
            fprintf(f, 'status    : enum("reserved","error","ignore") # if tuple is missing, the job is available\n');
            fprintf(f, 'key=null           : blob                     # structure containing the key\n');
            fprintf(f, 'error_message=""   : varchar(1023)            # error message returned if failed\n');
            fprintf(f, 'error_stack=null   : blob                     # error stack if failed\n');
            fprintf(f, 'host=""            : varchar(255)             # system hostname\n');
            fprintf(f, 'pid=0              : int unsigned             # system process id\n');
            fprintf(f, 'timestamp=CURRENT_TIMESTAMP : timestamp       # automatic timestamp\n');
            fprintf(f, '%%}\n\n');
            fprintf(f, 'classdef Jobs < dj.Jobs\n');
            fprintf(f, 'end\n');
            fclose(f);
        end
        
        
        function populateSanityChecks(self)
            % Performs sanity checks that are common to populate,
            % parpopulate and batch_populate.
            % To disable the sanity check: dj.set('populateCheck',false)
            if dj.set('populateCheck')
                source = self.getKeySource;
                abovePopRel = setdiff(self.primaryKey(1:min(end,length(source.primaryKey))), source.primaryKey);
                if ~all(ismember(source.primaryKey, self.primaryKey))
                    warning(['The keySource primary key contains extra fields. ' ...
                        'The keySource''s  primary key is normally a subset of the populated relation''s primary key'])
                end
                if ~isempty(abovePopRel)
                    warning(['Primary key attribute %s is above keySource''s primary key attributes. '...
                        'Transaction timeouts may occur. See DataJoint tutorial and issue #6'], abovePopRel{1})
                end
            end
        end
    end
end
