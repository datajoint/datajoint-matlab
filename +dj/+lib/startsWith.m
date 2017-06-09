function ret = startsWith(s, pattern)
% a MATLAB version-safe function that checks whether the string s
% starts with the given pattern

ret = strncmp(s, pattern, length(pattern));

end

