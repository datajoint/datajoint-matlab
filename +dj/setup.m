function setup(varargin)
    p = inputParser;
    addOptional(p, 'force', false);
    addOptional(p, 'prompt', true);
    parse(p, varargin{:});
    force = p.Results.force;
    prompt = p.Results.prompt;
    persistent INVOKED
    if ~isempty(INVOKED) && ~force
        return
    end
    % check MATLAB
    if verLessThan('matlab', '9.1')
        error('DataJoint:System:UnsupportedMatlabVersion', ...
              'MATLAB version 9.1 (R2016b) or greater is required');
    end
    % require certain toolboxes
    requiredToolboxes = {...
        struct(...
            'Name', 'GHToolbox', ...
            'ResolveTarget', 'datajoint/GHToolbox'...
        ), ...
        struct(...
            'Name', 'mym', ...
            'ResolveTarget', 'datajoint/mym', ...
            'Version', @(v) compareVersions(v, '2.8.0', @(v_actual,v_ref) v_actual>=v_ref)...
        )...
    };
    try
        ghtb.require(requiredToolboxes, 'prompt', prompt);
    catch ME
        installPromptMsg = {
            'Toolbox ''%s'' did not meet the minimum requirements.'
            'Would you like to proceed with an upgrade?'
        };
        if strcmp(ME.identifier, 'MATLAB:undefinedVarOrClass') && (~prompt || strcmpi('yes',...
                dj.internal.ask(sprintf(sprintf('%s\n', installPromptMsg{:}), 'GHToolbox'))))
            % fetch
            tmp_toolbox = [tempname '.mltbx'];
            websave(tmp_toolbox, ['https://github.com/' requiredToolboxes{1}.ResolveTarget ...
                                  '/releases/download/' ...
                                  subsref(webread(['https://api.github.com/repos/' ...
                                                   requiredToolboxes{1}.ResolveTarget ...
                                                   '/releases/latest'], ...
                                                  weboptions('Timeout', 60)), ...
                                          substruct('.', 'tag_name')) ...
                                  '/GHToolbox.mltbx'], weboptions('Timeout', 60));
            % install
            try
                matlab.addons.install(tmp_toolbox, 'overwrite');
            catch ME
                if strcmp(ME.identifier, 'MATLAB:undefinedVarOrClass')
                    matlab.addons.toolbox.installToolbox(tmp_toolbox);
                else
                    rethrow(ME);
                end
            end
            % remove temp toolbox file
            delete(tmp_toolbox);
            % retrigger dependency validation
            ghtb.require(requiredToolboxes, 'prompt', prompt);
        elseif strcmp(ME.identifier, 'MATLAB:undefinedVarOrClass')
            GHToolboxMsg = {
                'Toolbox ''GHToolbox'' did not meet the minimum requirements.'
                'Please proceed to install it.'
            };
            error('DataJoint:verifyGHToolbox:Failed', ...
                  sprintf('%s\n', GHToolboxMsg{:}));
        else
            rethrow(ME)
        end
    end
    % check mym
    mymVersion = mym('version');
    assert(mymVersion.major > 2 || mymVersion.major==2 && mymVersion.minor>=6, ...
           'DataJoint:System:mYmIncompatible', ...
           'Outdated version of mYm.  Please upgrade to version 2.6 or later');
    % set cache
    INVOKED = true;
end