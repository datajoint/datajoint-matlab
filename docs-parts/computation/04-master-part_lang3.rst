
``+test/ArrayResponse.m``

.. code-block:: matlab

  %{
  -> Probe
  array: int
  %}
  classdef ArrayResponse < dj.Computed
      methods(Access=protected)
          function make(self, key)
              self.insert(key)
              make(test.ArrayResponseElectrodeResponse, key)
          end
      end
  end

``+test/ArrayResponseElectrodeResponse.m``

.. code-block:: matlab

  %{
  -> test.ArrayResponse
  electrode : int % electrode number on the probe
  %}
  classdef ArrayResponseElectrodeResponse < dj.Part
      methods(SetAccess=protected)
          function make(self, key)
              self.insert(key)
          end
      end
  end

``+test/ArrayResponseChannelResponse.m``

.. code-block:: matlab

  %{
  -> test.ArrayResponseElectrodeResponse
  channel: int
  ---
  response: longblob  % response of a channel
  %}
  classdef ArrayResponseChannelResponse < dj.Part
      methods(SetAccess=protected)
          function make(self, key)
              self.insert(key)
          end
      end
  end
