
In MATLAB, the master and part tables are declared in a separate ``classdef`` file.
The name of the part table must begin with the name of the master table.
The part table must declare the property ``master`` containing an object of the master.

``+test/Segmentation.m``

.. code-block:: matlab

    %{
    # image segmentation
    -> test.Image
    %}
    classdef Segmentation < dj.Computed
        methods(Access=protected)
            function make(self, key)
                self.insert(key)
                make(test.SegmentationRoi, key)
            end
        end
    end

``+test/SegmentationROI.m``

.. code-block:: matlab

   %{
   # Region of interest resulting from segmentation
   -> test.Segmentation
   roi  : smallint   # roi number
   ---
   roi_pixels  : longblob   #  indices of pixels
   roi_weights : longblob   #  weights of pixels
   %}

   classdef SegmentationROI < dj.Part
       properties(SetAccess=protected)
           master = test.Segmentation
       end
       methods
           function make(self, key)
               image = fetch1(test.Image & key, 'image');
               [roi_pixels, roi_weighs] = mylib.segment(image);
               for roi=1:length(roi_pixels)
                   entity = key;
                   entity.roi_pixels = roi_pixels{roi};
                   entity.roi_weights = roi_weights{roi};
                   self.insert(entity)
               end
           end
       end
   end
