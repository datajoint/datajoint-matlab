A ``TableAccessor`` object is created as a property of a schema during each schema's creation.
This property is named ``schema.v``, for *virtual class generator*.
The ``TableAccessor`` ``v`` itself has properties that refer to the tables of the schema.
For example, one can access the ``Session`` table using ``schema.v.Session`` with no need for any ``Session`` class to exist in MATLAB.
Tab completion of table names is possible because the table names are added as dynamic properties of ``TableAccessor``.
