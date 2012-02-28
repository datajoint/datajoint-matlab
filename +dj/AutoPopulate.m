% abstract class that allows a dj.Relvar to automatically populate its table.
%
% The deriving class must also derive from dj.Relvar and must define
% properties 'table' of type dj.Table and 'popRel' of type dj.Relvar.
%
% The derived class must define the callback function makeTuples(self, tuple),
% which computes adds new fields to tuple and inserts it into the table as
% self.insert(key)
%
% A critical concept to understand is the populate relation.  It must be
% defined in the derived class' property popRel.  The populate relation
% determines the scope and granularity of makeTuples calls.
%
% Once self.makeTuples(key) and self.popRel are defined, the user may
% invoke self.populate to populate the table.

classdef AutoPopulate < handle
    
    properties(Access=private)
        jobKey   % currently reserved job
        jobRel   % the job reservation table (if any)
    end
    
    methods
        
        function self = AutoPopulate
            try
                assert(isa(self, 'dj.Relvar'))
                assert(isa(self.table, 'dj.Table'))
                assert(isa(self.popRel, 'dj.Relvar') || isa(self.popRel,'function_handle'))
            catch  %#ok
                error(['an AutoPopulate class must be derived from dj.Relvar ' ...
                    'and define properties ''table'' and ''popRel'''])
            end
            assert(ismember(self.table.info.tier, {'imported','computed'}), ...
                'AutoPopulate tables can only be "imported" or "computed"')
        end
        
    end
    
    methods(Abstract)
        
        makeTuples(self, key)
        % makeTuples(self, key) must be defined by each automatically
        % populated relvar. makeTuples copies key as tuple, adds computed
        % fields to tuple and inserts tuple as self.insert(tuple)
        
    end
    
    methods
        
        function varargout = parPopulate(self, jobRel, varargin)
            % dj.AutoPopulate/parPopulate - same as populate but with job
            % reservation for distributed processing.
            
            assert(isa(jobRel,'dj.Relvar'), ...
                'The second input must be a job reservation relvar');
            assert(all(ismember(jobRel.primaryKey, [self.primaryKey,{'table_name'}])), ...
                'The job table''s primary key fields must be a subset of populated table fields');
            
            self.jobRel = jobRel;
            [varargout{1:nargout}] = self.populate(varargin{:});
            self.jobRel = [];
            self.jobKey = [];
        end
        
        
        
        function [failedKeys, errors] = populate(self, varargin)
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
            % See also dj.Relvar/fetch, dj.Relvar/minus, dj.Relvar/and.
            %
            % Without any output arguments, populate rethrows any error
            % that occurs in makeTuples and terminates. However, if output
            % arguments are requested, errors are caught and accumuluated
            % in output arguments.
            %
            % EXAMPLES:
            %   populate(OriMaps)   % populate all OriMaps
            %   populate(OriMaps, 'mouse_id=12')    % populate OriMaps for mouse 12
            %   [failedKeys, errs] = populate(OriMaps);  % skip errors and return their list
            
            assert(~self.isRestricted, ...
                'Cannot populate a restricted relation. Correct syntax: populate(rel, restriction)')
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            
            if nargout > 0
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            unpopulated = self.popRel;
            if isa(unpopulated, 'function_handle')
                unpopulated = unpopulated();
            end
            assert(isa(unpopulated, 'dj.Relvar'), 'property popRel must be a dj.Relvar')
            unpopulated = fetch((unpopulated & varargin) - self);
            if isempty(unpopulated)
                disp 'Nothing to populate'
            else
                if numel(self.jobRel)
                    jobFields = self.jobRel.primaryKey(1:end-1);
                    unpopulated = dj.utils.structSort(unpopulated, jobFields);
                end
                fprintf('\n** Found %d unpopulated keys\n\n', length(unpopulated))
                for key = unpopulated'
                    if self.setJobStatus(key, 'reserved')    % this also marks previous job as completed
                        self.schema.conn.startTransaction
                        % check again in case a parallel process has already populated
                        if count(self & key)
                            self.schema.conn.cancelTransaction
                        else
                            fprintf('Populating %s for:\n', class(self))
                            disp(key)
                            try
                                % do the work
                                self.makeTuples(key)
                                self.schema.conn.commitTransaction
                            catch err
                                fprintf('\n** Error while executing %s.makeTuples:\n', class(self))
                                fprintf('%s: line %d\n', err.stack(1).file, err.stack(1).line);
                                fprintf('"%s"\n\n',err.message)
                                self.schema.conn.cancelTransaction
                                self.setJobStatus(key, 'error', err.message, err.stack);
                                if nargout > 0
                                    failedKeys = [failedKeys; key]; %#ok<AGROW>
                                    errors = [errors; err];         %#ok<AGROW>
                                elseif ~numel(self.jobRel)
                                    % rethrow error only if it's not already returned or logged.
                                    rethrow(err)
                                end
                            end
                        end
                    end
                end
                % complete the last job if non-empty
                self.setJobStatus(key, 'completed');
            end
        end
    end
    
    
    
    
    
    methods(Access = private)
        
        function success = setJobStatus(self, key, status, errMsg, errStack)
            % dj.AutoPopulate/setJobStatus - update job process for parallel
            % execution.
            
            % If self.jobRel is not set, skip job management
            success = ~numel(self.jobRel);
            
            if ~success
                key.table_name = ...
                    sprintf('%s.%s', self.schema.dbname, self.table.info.name);
                switch status
                    case {'completed','error'}
                        % if no key checked out, do nothing. This may
                        % happen if an error has already been logged and
                        % the final "completed" is being submitted.
                        if ~isempty(self.jobKey)
                            % assert that the completed job matches the reservation
                            assert(~isempty(dj.utils.structJoin(key, self.jobKey)),...
                                'job key mismatch ')
                            key = dj.utils.structPro(key, self.jobRel.primaryKey);
                            key.job_status = status;
                            if strcmp(status, 'error')
                                key.error_message = errMsg;
                                key.error_stack = errStack;
                            end
                            self.jobRel.insert(key, 'REPLACE')
                            self.jobKey = [];
                        end
                        success = true;
                        
                    case 'reserved'
                        % check if the job is already ours
                        success = ~isempty(self.jobKey) && ...
                            ~isempty(dj.utils.structJoin(key, self.jobKey));
                        
                        if ~success
                            % mark previous job completed
                            if ~isempty(self.jobKey)
                                self.jobKey.job_status = 'completed';
                                self.jobRel.insert(self.jobKey, 'REPLACE');
                            end
                            
                            % create the new job key
                            self.jobKey = dj.utils.structPro(key, self.jobRel.primaryKey);
                            
                            % check if the job is available
                            try
                                self.jobRel.insert(...
                                    setfield(self.jobKey,'job_status',status))  %#ok
                                disp '** reserved job:'
                                disp(self.jobKey)
                                success = true;
                            catch %#ok
                                % job already reserved
                                disp '** skipped unavailable job:'
                                disp(self.jobKey);
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