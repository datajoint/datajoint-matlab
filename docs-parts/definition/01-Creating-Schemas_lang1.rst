
A schema can be created either automatically using the ``dj.createSchema`` script or manually.
While ``dj.createSchema`` simplifies the process, the manual approach yields a better understanding of what actually takes place, so both approaches are listed below.

Manual
^^^^^^^^^^^^
**Step 1.**  Create the database schema

Use the following command to create a new schema on the database server:

.. code-block:: matlab

    query(dj.conn, 'CREATE SCHEMA `alice_experiment`')

Note that you must have create privileges for the schema name pattern (as described in :ref:`hosting`).
It is a common practice to grant all privileges to users for schemas that begin with the username, in addition to some shared schemas.
Thus the user ``alice`` would be able to perform any work in any schema that begins with ``alice_``.

**Step 2.**  Create the MATLAB package

DataJoint organizes schemas as MATLAB **packages**.
If you are not familiar with packages, please review:

* `How to work with MATLAB packages <https://www.mathworks.com/help/matlab/matlab_oop/scoping-classes-with-packages.html>`_
* `How to manage MATLAB's search paths <https://www.mathworks.com/help/matlab/search-path.html>`_

In your project directory, create the package folder, which must begin with a ``+`` sign.
For example, for the schema called ``experiment``, you would create the folder ``+experiment``.
Make sure that your project directory (the parent directory of your package folder) is added to the MATLAB search path.

**Step 3.**  Associate the package with the database schema

This step tells DataJoint that all classes in the package folder ``+experiment`` will work with tables in the database schema ``alice_experiment``.
Each package corresponds to exactly one schema.
In some special cases, multiple packages may all relate to a single database schema, but in most cases there will be a one-to-one relationship between packages and schemas.

In the ``+experiment`` folder, create the file ``getSchema.m`` with the following contents:

.. code-block:: matlab

    function obj = getSchema
    persistent OBJ
    if isempty(OBJ)
        OBJ = dj.Schema(dj.conn, 'experiment', 'alice_experiment');
    end
    obj = OBJ;
    end

This function returns a persistent object of type ``dj.Schema``, establishing the link between the ``experiment`` package in MATLAB and the schema ``alice_experiment`` on the database server.

Automatic
^^^^^^^^^^^^^

Alternatively, you can execute

.. code-block:: matlab

    >> dj.createSchema

This automated script will walk you through the steps 1--3 above and will create the schema, the package folder, and the ``getSchema`` function in that folder.
