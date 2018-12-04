
.. code-block:: matlab

    % Plot all the tables directly downstream from ``seq.Genome``:
    draw(dj.ERD(seq.Genome)+1)

.. code-block:: matlab

    % Plot all the tables directly upstream from ``seq.Genome``:
    draw(dj.ERD(seq.Genome)-1)

.. code-block:: matlab

    % Plot the local neighborhood of ``seq.Genome``
    draw(dj.ERD(seq.Genome)+1-1+1-1)
