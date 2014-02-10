function out = set(name, value)
% dj.set  - display, get, or set a DataJoint setting
%
% USAGE:
%    dj.set  - view current settings
%    v = dj.set('settingName')  - get the value of a setting
%    oldValue = dj.set('settingName', value) - set the value of a setting
%    dj.set('restore') - restore defaults

persistent STATE
if isempty(STATE) || (nargin>=1 && strcmpi(name,'restore'))
    STATE = struct(...
        'suppressPrompt', false, ...
        'reconnectTimedoutTransaction', true, ...
        'populateCheck', true, ...
        'tableErdRadius', [2 1] ...
        );
end

if ~nargin && ~nargout
    disp(STATE)
end
if nargout
    out = STATE;
end
if nargin
    assert(ischar(name), 'Parameter name must be a string')
    assert(isfield(STATE,name), 'Parameter name does not exist')
end
if nargin==1
    out = STATE.(name);
end
if nargin==2
    if nargout
        out = STATE.(name);
    end
    STATE.(name) = value;
end