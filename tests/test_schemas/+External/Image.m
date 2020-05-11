%{
-> External.Dimension
---
img=null  : blob@main
%}
classdef Image < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            dim = num2cell(fetch1(External.Dimension & key, 'dimension'));
            rng(5);
            key.img = rand(dim{:});
            self.insert(key)
        end
    end
end