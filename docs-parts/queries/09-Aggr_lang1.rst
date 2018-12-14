
.. code-block:: matlab

  % Number of students in each course section
  university.Section.aggr(university.Enroll, 'count(*)->n')
  % Average grade in each course
  university.Course.aggr(university.Grade * university.LetterGrade, 'avg(points)->avg_grade')
