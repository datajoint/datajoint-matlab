
Delete the entire contents of the table ``tuning.VonMises`` and all its dependents:

.. code-block:: matlab

    % delete all entries from tuning.VonMises
    del(tuning.VonMises)

    % delete entries from tuning.VonMises for mouse 1010
    del(tuning.VonMises & 'mouse=1010')

    % delete entries from tuning.VonMises except mouse 1010
    del(tuning.VonMises - 'mouse=1010')
