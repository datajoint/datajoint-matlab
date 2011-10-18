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
    
    properties(SetAccess=private)
        jobKey
        jobTable
    end
    
    
    methods
        function self = AutoPopulate
            try
                assert(isa(self, 'dj.Relvar'))
                assert(isa(self.table, 'dj.Table'))
                assert(isa(self.popRel, 'dj.Relvar'))
            catch  %#ok
                error 'an AutoPopulate class must be derived from dj.Relvar and define properties ''table'' and ''popRel'''
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
        
        function varargout = parPopulate(self, jobTable, varargin)
            % dj.AutoPopulate/parPopulate - same as populate but with job
            % reservation for distributed processing.
 
            assert(isa(jobTable,'dj.Relvar'), ...
                'The second input must be a job reservation relevar');  
            assert(all(ismember(jobTable.primaryKey, [self.primaryKey,{'table_name'}])), ...
                'The job table''s primary key fields must be a subset of populated table fields');
            
            self.jobTable = jobTable;
            [varargout{1:nargout}] = self.populate(varargin{:});
            self.jobTable = [];
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
            
            self.schema.cancelTransaction  % rollback any unfinished transaction
            
            if nargout > 0
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            unpopulatedKeys = fetch((self.popRel - self) & varargin);
            if ~isempty(unpopulatedKeys)
                if ~isempty(self.jobTable)
                    jobFields = self.jobTable.table.primaryKey(1:end-1);
                    unpopulatedKeys = dj.utils.structSort(unpopulatedKeys, jobFields);
                end
                for key = unpopulatedKeys'
                    if self.setJobStatus(key, 'reserved')    % this also marks previous job as completed
                        self.schema.startTransaction
                        % check again in case a parallel process has already populated
                        if count(self & key)
                            self.schema.cancelTransaction
                        else
                            fprintf('Populating %s for:\n', class(self))
                            disp(key)
                            try
                                % do the work
                                self.makeTuples(key)
                                self.schema.commitTransaction
                            catch err
                                self.schema.cancelTransaction
                                self.setJobStatus(key, 'error', err.message, err.stack);
                                if nargout > 0
                                    failedKeys = [failedKeys; key]; %#ok<AGROW>
                                    errors = [errors; err];         %#ok<AGROW>
                                elseif isempty(self.jobTable)
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
            % dj.AutoPopulate/setJobStatus - manage jobs
            % This processed is used by dj.AutoPopulate/populate to reserve
            % jobs for distributed processing. Jobs are managed only when a
            % job manager is specified using dj.Schema/setJobManager
            
            % if no job manager, do nothing
            success = isempty(self.jobTable);
            
            if ~success
                key.table_name = ...
                    sprintf('%s.%s', self.schema.dbname, self.table.info.name);
                switch status
                    case {'completed','error'}
                        % check that this is the matching job
                        if ~isempty(self.jobKey)
                            assert(~isempty(dj.utils.structJoin(key, self.jobKey)),...
                                'job key mismatch ')
                            self.jobKey = [];
                        end
                        key = dj.utils.structPro(key, self.jobTable.primaryKey);
                        key.job_status = status;
                        if nargin>3
                            key.error_message = errMsg;
                        end
                        if nargin>4
                            key.error_stack = errStack;
                        end
                        self.jobTable.insert(key, 'REPLACE')
                        success = true;
                        
                    case 'reserved'
                        % check if the job is already ours
                        success = ~isempty(self.jobKey) && ...
                            ~isempty(dj.utils.structJoin(key, self.jobKey));
                        
                        if ~success
                            % mark previous job completed
                            if ~isempty(self.jobKey)
                                self.jobKey.job_status = 'completed';
                                self.jobTable.insert(...
                                    self.jobKey, 'REPLACE');
                            end
                            
                            % create the new job key
                            self.jobKey = dj.utils.structPro(key, self.jobTable.primaryKey);
                            
                            % check if the job is available
                            try
                                self.jobTable.insert(...
                                    setfield(self.jobKey,'job_status',status))  %#ok
                                disp 'RESERVED JOB:'
                                disp(self.jobKey)
                                success = true;
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