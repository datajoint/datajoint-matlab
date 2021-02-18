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
            
            jobkey = struct('key_hash', dj.key_hash(key));
            fprintf('before')
            Lab.Jobs() & jobkey
            
            del(Lab.Jobs() & jobkey
            
            fprintf('after')
            Lab.Jobs() & jobkey

            if isempty(j)
                key.session_analysis = key.session_id;
            else
                key.session_analysis = j;
            end
            
            insert(self, key);

        end
    end
end
