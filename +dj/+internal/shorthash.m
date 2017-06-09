function s = shorthash(varargin)
s = dj.internal.hash(varargin{:});
s = s(1:8);