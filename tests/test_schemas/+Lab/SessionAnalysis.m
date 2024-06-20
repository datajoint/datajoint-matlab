%{
# SessionAnalysis
-> Lab.Session
---
session_analysis: longblob
%}
classdef SessionAnalysis < dj.Computed
    methods(Access=protected)
        function makeTuples(self,key)

            c = self.schema.conn;
            r = sprintf('connection_id = %d', c.serverId);

            j = fetch(Lab.Jobs() & r, '*');
            
            if isempty(j)
                key.session_analysis = key.session_id;
            else
                key.session_analysis = j;
            end
            
            insert(self, key);

        end
    end
end
