.. note::

  ``dj.U`` is not yet implemented in MATLAB.
  The feature will be added in an upcoming release: https://github.com/datajoint/datajoint-matlab/issues/144

.. code-block:: matlab

  % All home cities of students
  dj.U('home_city', 'home_state') & university.Student

  % Total number of students from each city
  aggr(dj.U('home_city', 'home_state'), university.Student, 'count(*)->n')

  % Total number of students from each state
  aggr(U('home_state'), university.Student, 'count(*)->n')

  % Total number of students in the database
  aggr(U(), university.Student, 'count(*)->n')
