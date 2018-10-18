
|matlab| MATLAB
---------------

In MATLAB the ``insert`` method inserts any number of entities in the form of a structure array with field attributes corresponding to the attribute names.

For example

.. code-block:: matlab

    s.username = 'alice';
    s.first_name = 'Alice';
    s.last_name = 'Cooper';
    insert(lab.Person, s)

For quick entry of multiple entities, we can take advantage of MATLAB's cell array notation:

.. code-block:: matlab

    insert(lab.Person, {
           'alice'   'Alice'   'Cooper'
           'bob'     'Bob'     'Dylan'
           'carol'   'Carol'   'Douglas'
    })

In this case, the values must match the order of the attributes in the table.
