
The ``exist`` method applied to a query object evaluates to ``true`` if the query returns any entities and to ``false`` if the query result is empty.

The ``count`` method applied to a query object determines the number of entities returned by the query.

.. code-block:: matlab

    % number of ephys sessions since the start of 2018.
    n = count(ephys.Session & 'session_date >= "2018-01-01"')

