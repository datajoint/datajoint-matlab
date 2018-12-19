``+test/RecordingModality.m``

.. code-block:: matlab

  %{
  modality : varchar(64)
  %}

  classdef RecordingModality < dj.Lookup
  end

``+test/MultimodalSession.m``

.. code-block:: matlab

  %{
  -> test.Session
  modes : int
  %}

  classdef MultimodalSession < dj.Manual
  end

``+test/MultimodalSessionSessionMode.m``

.. code-block:: matlab

  %{
  -> test.MultimodalSession
  -> test.RecordingModality
  %}

  classdef MultimodalSessionSessionMode < dj.Part
  end
