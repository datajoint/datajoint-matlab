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
                assert(isa(self.table, 'dj.Table'))    %#ok
                assert(isa(self.popRel, 'dj.Relvar'))  %#ok
            catch  %#ok
                error 'an AutoPopulate class must be derived from dj.Relvar and define properties ''table'' and ''popRel'''
            end
            assert(ismember(self.table.info.tier, {'imported','computed'}), ...
                'AutoPopulate tables can only be "imported" or "computed"')  %#ok
            assert(ismethod(self, 'makeTuples'), 'an AutoPopulate object must define method makeTuples(obj, key)')
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
            % See help dj.Relvar/fetch, dj.Relvar/minus, dj.Relvar/and.
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
            
            if nargout
                failedKeys = struct([]);
                errors = struct([]);
            end
            
            unpopulatedKeys = fetch((self.popRel - self) & varargin);
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
                if setJobStatus(key, 'reserved')
                    self.schema.startTransaction
                    try
                        % check again in case a parallel process has already populated
                        if count(self & key)
                            self.schema.cancelTransaction
                        else
                            % populate for the key
                            fprintf('Populating %s for:\n', class(self))
                            disp(key)
                            self.makeTuples(key)
                            self.schema.commitTransaction
                        end
                    catch err
                        self.schema.cancelTransaction
                        setJobStatus(key, 'error', err.message, err.stack);
                        if nargout
                            failedKeys = [failedKeys; key]; %#ok<AGROW>
                            errors = [errors; err];         %#ok<AGROW>
                        else
                            if isempty(self.schema.jobReservations)
                                rethrow(err)
                            end
                        end
                    end
                end
            end
            setJobStatus(key, 'completed');
            
            
            function success = setJobStatus(key, status, varargin)
                key.table_name = self.table.info.name;
                success = self.schema.setJobStatus(key, status, varargin{:});
            end
        end
    end
end