
.. code-block:: matlab

  % Number of students in each course section
  university.Section.aggr(university.Enroll, n: count())
  % Average grade in each course
  university.Course.aggr(university.Grade * university.LetterGrade, avg_grade: avg(points))

