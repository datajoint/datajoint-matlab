``+test/EEGRecording.m``

.. code-block:: matlab

  %{
  -> test.Session
  eeg_recording_id : int
  ---
  eeg_system : varchar(64)
  num_channels : int
  %}

  classdef EEGRecording < dj.Manual
  end

``+test/ChannelData.m``

.. code-block:: matlab

  %{
  -> test.EEGRecording
  channel_idx : int
  ---
  channel_data : longblob
  %}

  classdef ChannelData < dj.Imported
  end
