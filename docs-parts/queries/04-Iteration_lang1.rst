
In the simple example below, iteration is used to display the names and values of the primary key attributes of each entity in the simple table or table expression ``tab``.

.. code-block:: matlab

    for key = tab.fetch()'
        disp(key)
    end

Note that the results returned by ``fetch`` must be transposed.
MATLAB iterates across columns, so the single column ``struct`` returned by ``fetch`` must be transposed into a single row.
