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
            
            % if the last input is numeric, interpret it as parforIdx
            parforIdx = 1;
            if nargin>1 && isnumeric(varargin{end})
                parforIdx = varargin{end};
                varargin(end) = [];
            end
            
            if nargout > 0
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            unpopulatedKeys = fetch((self.popRel - self) & varargin);
            if ~isempty(unpopulatedKeys)
                if ~isempty(self.schema.jobReservations)
                    jobFields = self.schema.jobReservations.table.primaryKey(1:end-1);
                    assert(all(isfield(unpopulatedKeys, jobFields)), ...
                        ['The primary key of job table %s is more specific than'...
                        ' the primary key of %s.popRel. Use a more general job table'], ...
                        class(self.schema.jobReservations), class(self));
                    % group unpopulated keys by job reservation
                    unpopulatedKeys = dj.utils.structSort(unpopulatedKeys, jobFields);
                end
                for key = unpopulatedKeys'
                    if setJobStatus(key, 'reserved')    % this also marks previous job as completed
                        self.schema.startTransaction
                        % check again in case a parallel process has already populated
                        if count(self & key)
                            self.schema.cancelTransaction
                        else
                            % populate for the key
                            fprintf('Populating %s for:\n', class(self))
                            disp(key)
                            try
                                self.makeTuples(key)
                                self.schema.commitTransaction
                            catch err
                                self.schema.cancelTransaction
                                setJobStatus(key, 'error', err.message, err.stack);
                                if nargout > 0
                                    failedKeys = [failedKeys; key]; %#ok<AGROW>
                                    errors = [errors; err];         %#ok<AGROW>
                                elseif isempty(self.schema.jobReservations)
                                    % rethrow error only if it's not
                                    % already returned or logged.
                                    rethrow(err)
                                end
                            end
                        end
                    end
                end
            end
            
            % complete the last job.
            setJobStatus(key, 'completed');
            
            function success = setJobStatus(key, status, varargin)
                key.table_name = sprintf('%s.%s', ...
                    self.schema.dbname, self.table.info.name);
                success = self.schema.setJobStatus(parforIdx, key, status, varargin{:});
            end
        end
    end
end