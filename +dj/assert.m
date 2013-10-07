function assert(ok, message, varargin)
% Datajoint-specific assert function
% dj.assert        - throws "assertion failed"
% dj.assert(false) - throws "assertion failed"
% dj.assert(false, message, v1, ..., vn)  - throws error message with
% values v1,...,vn replacing conversion specifiers in string message
%
% message has the form or '[!][identifier:]error message'
%
% If message starts with a !, a warning is given rather than an error.
%
% If the identifier is omitted, the name of the calling function is used.

ok = nargin>=1 && ok;

if ~ok
    if nargin<2
        message = 'assertion failed';
    end
    isWarning = message(1)=='!';
    if isWarning
        message = message(2:end);
    end
    
    p = find(message==':',1,'first');
    if isempty(p)
        s = dbstack;
        if length(s)<2
            identifier = 'DataJoint:user';
        else
            [~,file,~] = fileparts(s(2).file);
            identifier = ['DataJoint:' file];
        end
    else
        identifier = ['DataJoint:' message(1:p-1)];
        message = message(p+1:end);
    end
    
    
    if isWarning
        warning(identifier,message,varargin{:})
    else
        throwAsCaller(MException(identifier,message,varargin{:}))
    end
end