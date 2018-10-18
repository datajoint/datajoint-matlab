
.. code-block:: matlab

  % All home cities of students
  dj.U('home_city', 'home_state') & university.Student
  % Total number of students from each city
  dj.U('home_city', 'home_state').aggr(university.Student, n: count())
  % Total number of students from each state
  U('home_state').aggr(university.Student, n: count())
  % Total number of students in the database
  U().aggr(university.Student, n: count())

