% dj.internal.External - an external static method class.
classdef ExternalMapping < handle
    properties
        schema
        tables
    end
    methods
        function self = ExternalMapping(schema)
            self.schema = schema;
            self.tables = struct();
        end
        function store_table = table(self, store)
            keys = fieldnames(self.tables);
            if all(~strcmp(store, keys))
                self.tables.(store) = dj.internal.ExternalTable(...
                    self.schema.conn, store, self.schema);
            end
            store_table = self.tables.(store);
        end
    end
end
