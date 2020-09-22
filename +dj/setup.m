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
            'ResolveTarget', 'guzman-raphael/mym', ...
            'Version', '2.7.3'...
        )...
    };
    try
        ghtb.require(requiredToolboxes, 'prompt', prompt);
    catch ME
        if strcmp(ME.identifier, 'MATLAB:undefinedVarOrClass')
            GHToolboxMsg = {
                'Toolbox ''GHToolbox'' did not meet the minimum minimum requirements.'
                'Please install it via instructions in '
                '''https://github.com/datajoint/GHToolbox'''.'
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