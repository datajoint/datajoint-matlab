function out = set(name, value)
% dj.set  - get or set a DataJoint setting
%
% USAGE:
%    dj.set  - view current settings
%    v = dj.set('settingName')  - get the value of a setting
%    oldValue = dj.set('settingName', value) - set the value of a setting
%    dj.set('restore') - restore defaults

persistent STATE
if isempty(STATE) || (nargin==1 && strcmpi(name,'restore'))
    % default settings
    STATE = struct( ...
        'suppressPrompt', false, ...
        'reconnectTimedoutTransaction', true, ...
        'populateCheck', true, ...
        'tableErdRadius', [2 1], ...
        'erdFontSize', 12, ...
        'verbose', false, ...
        'populateAncestors', false, ...
        'bigint_to_double', false, ...
        'ignore_extra_insert_fields', false);
end

if ~nargin && ~nargout
    disp(STATE)
elseif nargout
    out = STATE;
end

if nargin~=1 || ~strcmpi(name, 'restore')    
    if nargin
        assert(ischar(name), 'Setting name must be a string')
        assert(isfield(STATE,name), 'Setting `%s` does not exist', name)
    end
    switch nargin
        case 1
            out = STATE.(name);
        case 2
            if nargout
                out = STATE.(name);
            end
            STATE.(name) = value;
    end
end
end
