function pass = getpass(prompt)
%GETPASS  Open up a dialog box for the user to enter password. Password
%will be hidden as the user enters text. You can pass in an optional
%argument prompt to be used as the dialog box title. Defaults to "Enter
%password".

if nargin < 1
    prompt = 'Enter password';
end

screenSize = get(0, 'ScreenSize');

% configure the diaglog box
hfig = figure( ...
    'Menubar',         'none', ...
    'Units',           'Pixels', ...
    'NumberTitle',     'off', ...
    'Resize',          'off', ...
    'Name',            prompt, ...
    'Position',        [(screenSize(3:4)-[300 75])/2 300 75], ...
    'Color',           [0.8 0.8 0.8], ...
    'WindowStyle',     'modal');

hpass = uicontrol( ...
    'Parent',          hfig, ...
    'Style',           'Text', ...
    'Tag',             'password', ...
    'Units',           'Pixels', ...
    'Position',        [51 30 198 18], ...
    'FontSize',        15, ...
    'BackGroundColor', [1 1 1]);

set(hfig,'KeyPressFcn',{@keypress_cb, hpass}, 'CloseRequestFcn','uiresume')

% wait for password entry
uiwait
pass = get(hpass,'userdata');
% remove the figure to prevent passwork leakage
delete(hfig)

  
function keypress_cb(hObj, data, hpass)
% Callback function to handle actual key strokes

    pass = get(hpass,'userdata');

    switch data.Key
        case 'backspace'
            pass = pass(1:end-1);
        case 'return'
            uiresume
            return
        otherwise
            % append the typed character
            pass = [pass data.Character];
    end
    set(hpass, 'userdata', pass)
    set(hpass, 'String', char('*' * sign(pass)))