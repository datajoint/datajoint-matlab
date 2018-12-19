.. code-block:: matlab

  %{
  -> Recording
  ---
  sample_rate : float
  eeg_data : longblob
  %}
  classdef EEG < dj.Imported

    methods
      function q = get.keySource(self)
        q = ephys.Recording & 'recording_type = "EEG"'
      end
    end

  end
