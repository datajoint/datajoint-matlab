% dj.AutoPopulate is an abstract mixin class that allows a dj.Relvar object
% to automatically populate its table.
%
% Derived classes must also inherit from dj.Relvar and must define the
% constant property 'popRel' of type dj.GeneralRelvar.
%
% Derived classes must define the callback function makeTuples(self, key),
% which computes new tuples for the given key and inserts them into the table as
% self.insert(tuple).
%
% The constant property 'popRel' must be defined in the derived class.
% dj.AutoPopulate/populate uses self.popRel to generate the list of unpopulated keys
% for which self.makeTuples() will be invoked. Thus popRel determines the scope
% and granularity of makeTuples calls.
%
% Once self.makeTuples and self.popRel are defined, the user may
% invoke methods poopulate or parpopulate to automatically populate the table.
%
% The method parpopulate works similarly to populate but it uses the job reservation
% table <package>.Jobs to enable execution by multiple processes in parallel.
%
% The job reservation table must be declated as <package>.Jobs in the same
% schema package as this computed table. You may query the job reservation.
% While the job is executing, the job status is set to "reserved". When the
% job is completed, the entry is removed. When the job ends in error, the
% status is set to "error" and the error stack is saved.

classdef AutoPopulate < handle
    
    properties(Constant,Abstract)
        popRel     % specify the relation providing tuples for which makeTuples is called.
    end
    
    properties(Access=protected)
        useReservations
        executionEngine
    end
    
    properties (Access=protected, Dependent)
        jobs
    end
    
    methods(Abstract,Access=protected)
        makeTuples(self, key)
        % makeTuples(self, key) must be defined by each automatically
        % populated relvar. makeTuples copies key as tuple, adds computed
        % fields to tuple and inserts tuple as self.insert(tuple)
    end
    
    methods
        function varargout = populate(self, varargin)
            % [failedKeys, errors] = populate(baseRelvar [, restrictors...])
            % populates a table based on the contents self.popRel
            %
            % The property self.popRel contains the relation that provides
            % the keys for which self must be populated.
            %
            % self.populate will call self.makeTuples(key) for every
            % key in self.popRel that does not already have matching tuples
            % in self.
            %
            % Additional input arguments contain restriction conditions
            % applied to self.popRel.  Therefore, all keys to be populated
            % are obtained as fetch((self.popRel - self) & varargin).
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
            % See also dj.AutoPopulate/parpopulate
            
            % perform error checks
            self.populateSanityChecks
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            self.useReservations = false;
            self.executionEngine = @(key, fun, args) fun(args{:});
            [varargout{1:nargout}] = self.populate_(varargin{:});
        end
        
        
        function varargout = parpopulate(self, varargin)
            % dj.AutoPopulate/parpopulate works identically to dj.AutoPopulate/populate
            % except that it uses a job reservation mechanism to enable multiple
            % processes to populate the same table in parallel without collision.
            %
            % To enable parpopulate, create the job reservation table
            % <package>.Jobs which must have the following declaration:
            %   %{
            %   package.Jobs (job)        # the job reservation table
            %   table_name : varchar(255) # className of the table
            %   key_hash   : char(32)     # key hash
            %   -----
            %   status                      : enum('reserved','error','ignore') # if tuple is missing, the job is available
            %   error_key=null              : blob                              # non-hashed key for errors only
            %   error_message=""            : varchar(1023)                     # error message returned if failed
            %   error_stack=null            : blob                              # error stack if failed
            %   timestamp=CURRENT_TIMESTAMP : timestamp                         # automatic timestamp
            %   %}
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
            % class and the 32-bit MD5 hash of the primary key. However, the
            % key is saved in a separate field for errors for debugging
            % purposes.
            % See also dj.AutoPopulate/populate
            
            % perform error checks
            self.populateSanityChecks
            
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            self.useReservations = true;
            self.executionEngine = @(key, fun, args) fun(args{:});
            [varargout{1:nargout}] = self.populate_(varargin{:});
        end
        
        function taskCore(self, key)
            % The work unit that is submitted to the cluster
            % or executed locally
            self.schema.conn.startTransaction()
            try
                self.makeTuples(key)
                self.schema.conn.commitTransaction
                self.setJobStatus(key, 'completed')
            catch err
                self.schema.conn.cancelTransaction
                self.setJobStatus(key, 'error', err.message, err.stack)
                rethrow(err)   % Make error visible to DCT / caller
            end
        end
        
        
        function status = getJobStatus(self, key)
            % Check the status of a job.  
            % Can also be ccomplished by viewing package.Jobs.  
            % See also dj.AutoPopulate/progress
            
            popKey = fetch(self.popRel & key);
            assert(isscalar(popKey), 'one job at a time please')
            jobKey = self.makeJobKey(popKey);
            if exists(self & popKey)
                status = 'computed';
            elseif exists(self.jobs & jobKey)
                status = fetch1(self.jobs & jobKey, 'status');
            else
                status = 'available';
            end
        end
        
        
        function jobs = get.jobs(self)
            % Return the jobs table associated with this class
            % The handle is cached and we create the table
            % on demand if necessary
            jobClassName = [self.schema.package '.Jobs'];
            if ~exist(jobClassName,'class')
                self.createJobTable()
                rehash path
            end
            jobs = eval(jobClassName);
        end
        
        
        function varargout = progress(self, varargin)
            % show progress (fraction populated)
            if ~isempty(self.restrictions)
                throwAsCaller(MException('DataJoint:invalidInput', ...
                    'Cannot populate a restricted relation. Correct syntax: progress(rel, restriction)'))
            end
            
            remaining = count((self.popRel&varargin) - self);
            if nargout
                % return remaning items if asking
                varargout{1} = remaining;
            else
                total = count(self.popRel&varargin);
                if ~total
                    disp 'Nothing to populate'
                elseif remaining==0
                    disp 'Fully populated.'
                else
                    fprintf('%2.2f%% complete (%d remaining)\n', 100-100*double(remaining)/double(total), remaining)
                end
            end
        end
    end
    
    
    methods(Access = protected)
        function [failedKeys, errors] = populate_(self, varargin)
            if nargout
                failedKeys = struct([]);
                errors = struct([]);
            end
            unpopulated = self.popRel;
            
            % if the last argument is a function handle, apply it to popRel.
            if ~isempty(varargin) && isa(varargin{end}, 'function_handle')
                unpopulated = varargin{end}(unpopulated);
                varargin{end}=[];
            end
            % restrict the popRel to unpopulated tuples
            unpopulated = fetch((unpopulated & varargin) - self);
            if isempty(unpopulated)
                fprintf('%s: Nothing to populate\n', self.table.className)
            else
                fprintf('\n**%s: Found %d unpopulated keys\n\n', self.table.className, length(unpopulated))
                
                for key = unpopulated'
                    if self.setJobStatus(key, 'reserved')
                        if exists(self & key)
                            % already populated
                            self.setJobStatus(key, 'completed')
                        else
                            fprintf('Populating %s for:\n', self.table.className)
                            disp(key)
                            try
                                % Perform or schedule computation
                                self.executionEngine(key, @taskCore, {self, key})
                            catch err
                                fprintf('\n** Error while executing %s.makeTuples:\n', class(self))
                                fprintf('%s: line %d\n', err.stack(1).file, err.stack(1).line)
                                fprintf('"%s"\n\n',err.message)
                                if nargout
                                    failedKeys = [failedKeys; key]; %#ok<AGROW>
                                    errors = [errors; err];         %#ok<AGROW>
                                else
                                    if ~self.useReservations
                                        % rethrow error only if not returned
                                        rethrow(err)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        
        function jobKey = makeJobKey(self, key)
            jobKey = struct('table_name', self.table.className, 'key_hash', dj.DataHash(key));
        end
        
        
        function success = setJobStatus(self, key, status, errMsg, errStack)
            % dj.AutoPopulate/setJobStatus - update job process for parallel execution.
            success = ~self.useReservations;
            if ~success
                jobKey = self.makeJobKey(key);
                if all(ismember({'host','pid'},{self.jobs.header.name}))
                    [~,host] = system('hostname');
                    jobKey.host = strtrim(host);
                    jobKey.pid = feature('getpid');
                end
                
                switch status
                    case 'completed'
                        delQuick(self.jobs & jobKey)
                    case 'error'
                        jobKey.status = status;
                        jobKey.error_key = key;
                        jobKey.error_message = errMsg;
                        jobKey.error_stack = errStack;
                        self.jobs.insert(jobKey,'REPLACE')
                    case 'reserved'
                        % this reservation process assumes that MySQL API
                        % will throw an error when inserting a duplicate entry.
                        success = ~exists(self.jobs & jobKey);
                        if success
                            jobKey.status = status;
                            try
                                self.jobs.insert(jobKey)
                                success = true;
                            catch %#ok<CTCH>
                                success = false;
                            end
                        end
                        if ~success
                            fprintf('** %s: skipping already reserved', self.table.className)
                            disp(key)
                        end
                end
            end
        end
        
        
        function createJobTable(self)
            % Create the Jobs class if it does not yet exist
            schemaPath = which([self.schema.package '.getSchema']);
            if isempty(schemaPath)
                throwAsCaller(MException('DataJoint:invalidSchema',...
                    sprintf('missing function %s.getSchema', self.schema.package)));
            end
            path = fullfile(fileparts(schemaPath), 'Jobs.m');
            f = fopen(path,'w');
            fprintf(f, '%% %s.Jobs -- job reservation table\n\n', self.schema.package);
            fprintf(f, '%%{\n');
            fprintf(f, '%s.Jobs (job)    # the job reservation table\n', self.schema.package);
            fprintf(f, 'table_name : varchar(255) # className of the table\n');
            fprintf(f, 'key_hash   : char(32)     # key hash\n');
            fprintf(f, '-----\n');
            fprintf(f, 'status    : enum("reserved","error","ignore") # if tuple is missing, the job is available\n');
            fprintf(f, 'error_key=null     : blob                              # non-hashed key for errors only\n');
            fprintf(f, 'error_message=""   : varchar(1023)                     # error message returned if failed\n');
            fprintf(f, 'error_stack=null   : blob                              # error stack if failed\n');
            fprintf(f, 'host=""            : varchar(255)                      # system hostname\n');
            fprintf(f, 'pid=0              : int unsigned                      # system process id\n');
            fprintf(f, 'timestamp=CURRENT_TIMESTAMP : timestamp                # automatic timestamp\n');
            fprintf(f, '%%}\n\n');
            fprintf(f, 'classdef Jobs < dj.Relvar\n');
            fprintf(f, '    properties(Constant)\n');
            fprintf(f, '        table = dj.Table(''%s.Jobs'')\n', self.schema.package);
            fprintf(f, '    end\n');
            fprintf(f, '    methods\n');
            fprintf(f, '        function self = Jobs(varargin)\n');
            fprintf(f, '            self.restrict(varargin)\n');
            fprintf(f, '        end\n');
            fprintf(f, '    end\n');
            fprintf(f, 'end\n');
            fclose(f);
        end
        
        
        function populateSanityChecks(self)
            % Performs sanity checks that are common to populate, parpopulate
            % and batch_populate
            if ~isempty(self.restrictions)
                throwAsCaller(MException('DataJoint:invalidInput', ...
                    'Cannot populate a restricted relation. Correct syntax: populate(rel, restriction)'))
            end
            if ~isa(self.popRel, 'dj.GeneralRelvar')
                throwAsCaller(MException('DataJoint:invalidInput', ...
                    'property popRel must be a subclass of dj.GeneralRelvar'))
            end
            if ~all(ismember(self.popRel.primaryKey, self.primaryKey))
                throwAsCaller(MException('DataJoint:invalidPopRel', ...
                    sprintf('%s.popRel''s primary key is too specific, move it higher in data hierarchy', class(self))))
            end
        end
    end
end
