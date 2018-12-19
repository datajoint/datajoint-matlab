Behavior of the ``populate`` method depends on the number of output arguments requested in the function call.
When no output arguments are requested, errors will halt population.
With two output arguments (``failedKeys`` and ``errors``), ``populate`` will catch any encountered errors and return them along with the offending keys.
