classdef Jobs < handle
    methods
        function self = Jobs
            try
                assert(isa(self, 'dj.Relvar'))
                assert(isa(self.table, 'dj.Table'))    %#ok
            catch  %#ok
                error 'a Jobs class must be derived from dj.Relvar and define a property named ''table'''
            end
            assert(ismember(self.table.info.tier, {'computed'}), ...
                'A Jobs tables can only be "computed"')  %#ok
            assert(ismethod(self, 'job'), 'a Jobs class must define method job(key)')
            assert(all(ismember({'job_status', 'error_message', 'error_stack'}, ...
                {self.table.fields.name})), ...
                'A Jobs table requires fields "job_status", "error_message" and "error_stack"')  %#ok
        end
        
        
        
        
        function execute(self, varargin)
            % construct the populate relation as the join of the direct
            % parents in the hierarchy
            popRel = self.schema.classNames(...
                self.schema.dependencies(...
                strcmp({self.schema.tables.name}, self.info.name),:)==1);
            assert(~isempty(popRel), 'a Jobs table must have parent tables')
            popRel = sprintf('*%s', popRel{:});    % join of parents
            unpopulatedKeys = fetch((eval(popRel(2:end))-self) & varargin);
            for key = unpopulatedKeys'
                jobKey = key;

                % reserve the job
                jobKey.job_status = 'reserved';
                try
                    self.insert(jobKey)
                catch  %#ok
                    continue
                end
                
                try
                    % do the job
                    self.job(key)
                    
                    % report job completed
                    jobKey.job_status = 'completed';
                    self.insert(jobKey, 'REPLACE')
                    
                catch e
                    % report job error
                    warning(e.message);
                    jobKey.job_status = 'error';
                    jobKey.error_message = e.message;
                    jobKey.error_stack   = e.stack;
                    self.insert(jobKey, 'REPLACE')
                end
            end
        end
    end
end