
.. code-block:: MATLAB

    %{
    # Filtered image
    -> test.Image
    ---
    filtered_image : longblob
    %}

    classdef FilteredImage < dj.Computed
        methods(Access=protected)
            function make(self, key)
                img = fetch1(test.Image & key, 'image');
                key.filtered_image = myfilter(img);
                self.insert(key)
            end
        end
    end

.. note:: Currently matlab uses ``makeTuples`` rather than ``make``.  This will be fixed in an upcoming release: https://github.com/datajoint/datajoint-matlab/issues/141

The ``make`` method receives one argument: the struct ``key`` containing the primary key value of an element of :ref:`key source <keysource>` to be worked on.
