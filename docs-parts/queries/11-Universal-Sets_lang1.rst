.. note::

  ``dj.U`` is not yet implemented in MATLAB.
  The feature will be added in an upcoming release: https://github.com/datajoint/datajoint-matlab/issues/144

.. code-block:: matlab

  % All home cities of students
  dj.U('home_city', 'home_state') & university.Student

  % Total number of students from each city
  dj.U('home_city', 'home_state').aggr(university.Student, 'count(*)->n')

  % Total number of students from each state
  U('home_state').aggr(university.Student, 'count(*)->n')

  % Total number of students in the database
aggr(U(), university.Student, 'count(*)->n')
