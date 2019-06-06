function createSchema(package,parentdir,db)
% DJ.CREATESCHEMA - interactively create a new DataJoint schema
%
% INPUT:
%   (optional) package - name of the package to be associated with the schema
%   (optional) parentdir - name of the dirctory where to create new package
%   (optional) db - database name to associate with the schema

if nargin < 3
    dbname = input('Enter database name >> ','s');
else
    dbname = db;
end

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

    if nargin < 1
        if usejava('desktop')
            disp 'Please select a package folder. Opening UI...'
            folder = uigetdir('./','Select a package folder');
        else
            folder = input('Enter package folder path >> ','s');
        end
    else
        if nargin < 3
            if usejava('desktop')
                fprintf('Please select folder to create package %s in. Opening UI...\n', ['+', package])
                folder = uigetdir('./', sprintf('Select folder to create package %s in', ['+', package]));
            else
                folder = input('Enter parent folder path >> ','s');
            end
        else
            folder = parentdir;
        end

        if folder
            folder = fullfile(folder, ['+', package]);
            mkdir(folder)
        end
    end

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
            fprintf('%s.getSchema.m already exists\n', package)
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
