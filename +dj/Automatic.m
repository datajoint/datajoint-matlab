% dj.Automatic is an abstract mixin class that allows a dj.Relvar object
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
% dj.Automatic/populate uses self.popRel to generate the list of unpopulated keys
% for which makeTuples will be invoked. Thus popRel determines the scope
% and granularity of makeTuples calls.
% 
% Once self.makeTuples and self.popRel are defined, the user may
% invoke self.populate to automatically populate the table.
%
% The method parpopulate works similarly to populate but it uses the job
% reservation table to reserve jobs thereby enabling multiple processes to
% populate the table without conflicts.
%
% The job reservation table must be declated as <package>.Jobs in the same
% schema package as this computed table. You may query the job reservation.
% While the job is executing, the job status is set to "reserved". When the
% job is completed, the entry is removed. When the job ends in error, the
% status is set to "error" and the error stack is saved.


classdef Automatic < handle
    
    properties(Constant,Abstract)
        popRel     % specify the relation providing tuples for which makeTuples is called.
    end
    
    methods(Abstract,Access=protected)
        makeTuples(self, key)
        % makeTuples(self, key) must be defined by each automatically
        % populated relvar. makeTuples copies key as tuple, adds computed
        % fields to tuple and inserts tuple as self.insert(tuple)
    end
    
    
    
    methods
        
        function varargout = parpopulate(self, varargin)
            % dj.Automatic/parpopulate works identically to dj.Automatic/populate.
            % The only differences is that papPopulate uses a job reservation
            % mechanism to enable multiple processes to work in parallel without
            % collision.
            %
            % Upon the first invokation of obj.parpopulate, it creates the
            % job reservation table that is specific to obj's table.
            % The job reservation table has the same name as the obj's
            % table prefixed with '~jobs_rsrv_'.
            %
            % A job is considered to available when the job reservation
            % table contains no matching entry.
            %
            % For each unpopulated key in popRel, parpopulate first inserts a tuple
            % with the job_status set to 'reserved'. Upon completion, the  status
            % is changed to 'completed'. If the job resulted in error, the status
            % is changed to 'error' and the error messaage is saved into the jobs table.
            %
            % Users must explicitly manage the contents of the jobs table once it
            % gets filled as it is not automatically cleared. Users can get access
            % to the jobs table through the 'jobs' property.
            
            if ~all(ismember(self.popRel.primaryKey, self.primaryKey))
                throwAsCaller(MException('DataJoint:invalidPopRel', ...
                    sprintf('%s.popRel''s primary key is too specific, move it higher in data hierarchy', class(self))))
            end
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            jobClassName = [self.schema.package '.Jobs'];
            try
                jobs_ = eval(jobClassName);
                assert(isa(jobs_, 'dj.Relvar'))
                self.jobs = jobs_;
            catch %#ok<CTCH>
                throwAsCaller(MException('DataJoint:missingJobs', 'Could not find class <package>.Jobs'))
            end
            
            self.useReservations = true;
            [varargout{1:nargout}] = self.populate_(varargin{:});
        end
        
        
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
            % See also dj.Relvar/fetch, dj.Relvar/minus, dj.Relvar/and.
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
            
            if ~isempty(self.restrictions)
                throwAsCaller(MException('DataJoint:invalidInput', ...
                    'Cannot populate a restricted relation. Correct syntax: populate(rel, restriction)'))
            end
            self.schema.conn.cancelTransaction  % rollback any unfinished transaction
            self.useReservations = false;
            [varargout{1:nargout}] = self.populate_(varargin{:});
        end
    end
    
    
    
    
    %%%% private stuff %%%%%
    
    
    properties(Access=private)
        useReservations
        jobs
    end
    
    
    methods(Access = private)
        
        function [failedKeys, errors] = populate_(self, varargin)
            % see populate
            
            if nargout
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            unpopulated = self.popRel;
            assert(isa(unpopulated, 'dj.GeneralRelvar'), ...
                'property popRel must be a subclass of dj.GeneralRelvar')
            unpopulated = fetch((unpopulated & varargin) - self);
            if isempty(unpopulated)
                disp 'Nothing to populate'
            else
                fprintf('\n** Found %d unpopulated keys\n\n', length(unpopulated))
                for key = unpopulated'
                    if self.setJobStatus(key, 'reserved')
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
                                self.setJobStatus(key, 'completed')
                            catch err
                                fprintf('\n** Error while executing %s.makeTuples:\n', class(self))
                                fprintf('%s: line %d\n', err.stack(1).file, err.stack(1).line);
                                fprintf('"%s"\n\n',err.message)
                                self.schema.conn.cancelTransaction
                                self.setJobStatus(key, 'error', err.message, err.stack)
                                if nargout
                                    failedKeys = [failedKeys; key]; %#ok<AGROW>
                                    errors = [errors; err];         %#ok<AGROW>
                                else
                                    % rethrow error only if not returned
                                    rethrow(err)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        
        function success = setJobStatus(self, key, status, errMsg, errStack)
            % dj.AutoPopulate/setJobStatus - update job process for parallel execution.
            if ~self.useReservations
                if strcmp(status,'reserved')
                    success = true;
                end
            else
                jobKey = struct('table_name', self.table.className, 'key_hash', dj.DataHash(key));
                switch status
                    case 'completed'
                        delQuick(self.jobs & jobKey);
                    case 'error'
                        tuple = jobKey;
                        tuple.status = status;
                        tuple.error_message = errMsg;
                        tuple.error_stack = errStack;
                        self.jobs.insert(tuple,'REPLACE')
                    case 'reserved'
                        % this reservation process relies on the API to
                        % throw an error when attempting to insert a
                        % duplicate without delay. (No delayed inserts)
                        try
                            tuple = jobKey;
                            tuple.status = status;
                            self.jobs.insert(tuple);
                            success = true;
                        catch %#ok<CTCH>
                            success = false;
                            disp '** skipped reserved job:'
                            disp(key)
                        end
                end
            end
        end
    end
end