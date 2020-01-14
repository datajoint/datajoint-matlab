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
            'queryPopulate_check', true, ...
            'queryPopulate_ancestors', false, ...
            'queryBigint_to_double', false, ...
            'queryIgnore_extra_insert_fields', false ...  when false, throws an error in `insert(self, tuple)` when tuple has extra fields.
        )
    end
    properties
        result
    end
    % methods
    %     function disp(self)
    %         disp(self.result);
    %     end
    % end
    methods(Static)
        function out = Settings(name, value)
            current_state = stateAccess;
            out.result = current_state;
            if nargin == 1 || nargin == 2
                assert(ischar(name), 'DataJoint:Config:InvalidType', 'Setting name must be a string');
%                 fieldPath = regexp(name, '[![a-zA-Z0-9_]]+', 'match');
%                 for i = 1:length(fieldPath)
%                     if ~isempty( sscanf( fieldPath{i}, '%f' ))
%                         fieldPath{i} = {str2double(fieldPath{i})};
%                     end
%                 end
                tkn = regexp(['.',name],'(\W)(\w+)','tokens');
                tkn = vertcat(tkn{:}).';
                tkn(1,:) = strrep(strrep(tkn(1,:),'{','{}'),'(','()');
                vec = str2double(tkn(2,:));
                idx = ~isnan(vec);
                tkn(2,idx) = num2cell(num2cell(vec(idx)));
                sbs = substruct(tkn{:});
                if nargout
                    try
%                         out.result = getfield(current_state, fieldPath{:});
                        % eval(['out.result = current_state.' name ';']);
                        out.result = subsref(current_state, sbs);
                    catch ME
                        switch ME.identifier
                            case 'MATLAB:nonExistentField'
                                error('DataJoint:Config:InvalidKey', 'Setting `%s` does not exist', name);
                            otherwise
                                rethrow(ME);
                        end
                    end                    
                else
                    out.result = [];
                end
            end
            if nargin == 2
                % does not currently support indexing into property...
%                 new_state = setfield(struct(), fieldPath{:}, value);
%                 stateAccess('set', new_state);
                % eval(['current_state.' name ' = ' value ';']);
                % stateAccess('set', current_state);
                new_state = subsasgn(current_state, sbs, value);
                stateAccess('set', new_state);
            end
        end
        function out = restore()
%             out = dj.internal.Settings;
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
            dj.internal.Settings.save(dj.internal.Settings.GLOBALFILE);
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
        newFields{i} = regexprep(regexp(raw, regexprep(newFields{i},'_','.'), 'match', 'once'),'\.[a-zA-Z0-9]','${upper($0(2))}');
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
    out = STATE;
    if any(strcmpi(operation, {'set', 'load'}))
        %issue here with nested change...
        STATE = rmfield(STATE, intersect(fieldnames(STATE), fieldnames(new)));
        names = [fieldnames(STATE); fieldnames(new)];
        STATE = orderfields(cell2struct([struct2cell(STATE); struct2cell(new)], names, 1));
        if strcmpi(operation, 'load')
            envVarUpdate();
        end
    end
end
% function [S, ref] = struct2cell_ultimate(S, ref, idx)
%     names = fieldnames(S);
%     S = struct2cell(S);
%     if isempty( sscanf( ref{idx}, '%f' ))
%         ref{idx} =  names == ref{idx};
%     end
% end
% function S = mod_struct(S, fields, value)
% %     names = fieldnames(S);
% %     S_cell = struct2cell_ultimate(S, fields, 1);

%     eval('j{2}{2}{2}{2}{1}')

%     if nargin == 3
%         S.(fields{1}) = value;
%     else
%         S = S.(fields{1});
%     end



% end