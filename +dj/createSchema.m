function newSchema

dbname = input('Enter database name >> ','s');

if ~dbname
    disp 'No database name entered. Quitting.'
elseif isempty(regexp(dbname,'^[a-z][a-z0-9_]*$','once'))
    error 'Invalid database name. Begin with a letter, only lowercase alphanumerical and underscores.'
else
    % create database
    s = query(dj.conn, ...
        sprintf('SELECT schema_name FROM information_schema.schemata WHERE schema_name = "%s"', dbname));
    
    if ~isempty(s.schema_name)
        disp 'database already exists'
    else
        query(dj.conn, sprintf('create schema %s',dbname))
        disp 'database created'
    end
    
    folder = uigetdir('./','Select of create package folder');
    
    if ~folder
        disp 'No package selected.  Cancelled.'
    else
        [filepath,package] = fileparts(folder);
        if package(1)~='+'
            error 'Package folders must start with a +'
        end
        package = package(2:end);  % discard +
        
        % create the getSchema function
        schemaFile = fullfile(folder,'getSchema.m');
        if exist(schemaFile,'file')
            fprintf('%s.getSchema.m already exists', package)
        else
            f = fopen(schemaFile,'wt');
            assert(-1 ~= f, 'Could not open %s', f)
            
            fprintf(f,'function obj = getSchema\n');
            fprintf(f,'persistent schemaObject\n');
            fprintf(f,'if isempty(schemaObject)\n');
            fprintf(f,'    schemaObject = dj.Schema(dj.conn, ''%s'', ''%s'');\n', package, dbname);
            fprintf(f,'end\n');
            fprintf(f,'obj = schemaObject;\n');
            fprintf(f,'end\n');
            fclose(f);
        end
        
        % test that getSchema is on the path
        whichpath = which(sprintf('%s.getSchema',package));
        if isempty(whichpath)
            warning('Could not open %s.getSchema. Ensure that %s is on the path', package, filepath)
        end
    end
end