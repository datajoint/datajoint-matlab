function ret = isString(s)
% a MATLAB version-safe function that tells returns true if 
% argument is a string or a character array
ret = ischar(s) || exist('isstring', 'builtin') && isstring(s) && isscalar(s);
end