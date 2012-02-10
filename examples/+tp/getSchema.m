function obj = getSchema
persistent schemaObject

if isempty(schemaObject)
    schemaObject = dj.Schema(dj.conn, 'tp', 'two_photon');
end

obj = schemaObject;
end