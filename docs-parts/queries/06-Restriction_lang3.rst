
.. code-block:: matlab

  % All the sessions performed by Alice
  ephys.Session & 'user = "Alice"'

  % All the experiments at least one minute long
  ephys.Experiment & 'duration >= 60'
