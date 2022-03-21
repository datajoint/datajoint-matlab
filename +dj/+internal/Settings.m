classdef Settings < matlab.mixin.Copyable
    properties (Constant)
        LOCALFILE = './dj_local_conf.json'
        GLOBALFILE = '~/.datajoint_config.json'
        DEFAULTS = struct( ...
            'databaseHost', 'localhost', ...
            'databasePassword', [], ...
            'databaseUser', [], ...
            'databasePort', 3306, ...
            'databaseUse_tls', [], ...
            'databaseReconnect_transaction', false, ...
            'connectionInit_function', [], ...
            'loglevel', 'INFO', ...
            'safemode', true, ...
            'displayLimit', 12, ... how many rows to display when previewing a relation
            'displayDiagram_hierarchy_radius', [2 1], ...    levels up and down the hierachy to display in `erd schema.Table`
            'displayDiagram_font_size', 12, ...  font size to use in ERD labels
            'displayCount', true, ... optionally display count of records in result
            'queryPopulate_check', true, ...
            'queryPopulate_ancestors', false, ...
            'queryBigint_to_double', false, ...
            'queryIgnore_extra_insert_fields', false, ...  when false, throws an error in `insert(self, tuple)` when tuple has extra fields.
            'use_32bit_dims', false ...
        )
    end
    properties
        result
    end
    methods(Static)
        function out = Settings(name, value)
            current_state = stateAccess;
            out.result = current_state;
            if nargin == 1 || nargin == 2
                assert(ischar(name), 'DataJoint:Config:InvalidType', ...
                    'Setting name must be a string');
                token = regexp(['.', name], '(\W)(\w+)', 'tokens');
                token = vertcat(token{:}).';
                token(1,:) = strrep(strrep(token(1,:), '{', '{}'), '(', '()');
                value_vector = str2double(token(2,:));
                index = ~isnan(value_vector);
                token(2, index) = num2cell(num2cell(value_vector(index)));
                subscript = substruct(token{:});
                if nargout
                    try
                        out.result = subsref(current_state, subscript);
                    catch ME
                        switch ME.identifier
                            case 'MATLAB:nonExistentField'
                                error('DataJoint:Config:InvalidKey', ...
                                    'Setting `%s` does not exist', name);
                            otherwise
                                rethrow(ME);
                        end
                    end                    
                else
                    out.result = [];
                end
            end
            if nargin == 2
                new_state = subsasgn(current_state, subscript, value);
                stateAccess('set', new_state);
                if strcmp(subscript(1).subs, 'use_32bit_dims')
                    ternary = @(varargin)varargin{end-varargin{1}};
                    setenv('MYM_USE_32BIT_DIMS', ternary(value, 'true', 'false'));
                end
            end
        end
        function out = restore()
            out = stateAccess('restore');
        end
        function save(fname)
            c = dj.internal.Settings;
            dj.lib.saveJSONfile(c.result, fname);
        end
        function load(fname)
            if ~nargin
                fname = dj.internal.Settings.LOCALFILE;
            end
            raw = fileread(fname);
            new_state = fixProps(jsondecode(raw), raw);
            stateAccess('load', new_state);
        end
        function saveLocal()
            dj.internal.Settings.save(dj.internal.Settings.LOCALFILE);
        end
        function saveGlobal()
            location = dj.internal.Settings.GLOBALFILE;
            if ispc
                location = strrep(location, '~', strrep(getenv('USERPROFILE'), '\', '/'));
            end
            dj.internal.Settings.save(location);
        end
    end
end
function data = fixProps(data, raw)
    newFields = fieldnames(data);
    for i=1:length(newFields) 
        for j=1:length(data.(newFields{i}))
            if isstruct(data.(newFields{i})(j))
                if exist('res','var')
                    res(end + 1) = fixProps(data.(newFields{i})(j), raw);
                else
                    res = fixProps(data.(newFields{i})(j), raw);
                end
                if j == length(data.(newFields{i}))
                    data.(newFields{i}) = res;
                    clear res;
                end
            end            
        end
        newFields{i} = regexprep(regexp(raw, ...
            regexprep(newFields{i},'_','.'), 'match', 'once'), ...
            '\.[a-zA-Z0-9]','${upper($0(2))}');
    end
    data = cell2struct(struct2cell(data), newFields);
end
function out = stateAccess(operation, new)
    function envVarUpdate()
        % optional environment variables specifying the connection.
        if getenv('DJ_HOST')
            STATE.databaseHost = getenv('DJ_HOST');
        end
        if getenv('DJ_USER')
            STATE.databaseUser = getenv('DJ_USER');
        end
        if getenv('DJ_PASS')
            STATE.databasePassword = getenv('DJ_PASS');
        end
        if getenv('DJ_INIT')
            STATE.connectionInit_function = getenv('DJ_INIT');
        end
    end
    switch nargin
        case 0
            operation = '';
        case 1
        case 2
        otherwise
        error('Exceeded 2 input limit.')
    end
    persistent STATE
    if (isempty(STATE) && ~strcmpi(operation, 'load')) || strcmpi(operation, 'restore')
        % default settings
        STATE = orderfields(dj.internal.Settings.DEFAULTS);
        if exist(dj.internal.Settings.LOCALFILE, 'file') == 2
            dj.internal.Settings.load(dj.internal.Settings.LOCALFILE);
        elseif exist(dj.internal.Settings.GLOBALFILE, 'file') == 2
            dj.internal.Settings.load(dj.internal.Settings.GLOBALFILE);
        end
        envVarUpdate();
    end
    % return STATE prior to change
    out = STATE;
    if any(strcmpi(operation, {'set', 'load'}))
        if isempty(STATE)
            STATE = rmfield(dj.internal.Settings.DEFAULTS, intersect(fieldnames( ...
                dj.internal.Settings.DEFAULTS), fieldnames(new)));
            names = [fieldnames(STATE); fieldnames(new)];
            STATE = orderfields(...
                cell2struct([struct2cell(STATE); struct2cell(new)], names, 1));
        else
            % merge with existing STATE
            STATE = rmfield(STATE, intersect(fieldnames(STATE), fieldnames(new)));
            names = [fieldnames(STATE); fieldnames(new)];
            STATE = orderfields(...
                cell2struct([struct2cell(STATE); struct2cell(new)], names, 1));
        end
        if strcmpi(operation, 'load')
            envVarUpdate();
        end
    end
end
