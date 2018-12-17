
The ``insert`` method inserts any number of entities in the form of a structure array with field names corresponding to the attribute names.

For example

.. code-block:: matlab

    s.username = 'alice';
    s.first_name = 'Alice';
    s.last_name = 'Cooper';
    insert(lab.Person, s)

Quick entry of multiple entities takes advantage of MATLAB's cell array notation:

.. code-block:: matlab

    insert(lab.Person, {
           'alice'   'Alice'   'Cooper'
           'bob'     'Bob'     'Dylan'
           'carol'   'Carol'   'Douglas'
    })

In this case, the values must match the order of the attributes in the table.

The optional parameter ``command`` can be either ``'IGNORE'`` or ``'REPLACE'``.
Duplicates, unmatched attributes, or missing required attributes will cause insert errors, unless ``command`` is specified.
