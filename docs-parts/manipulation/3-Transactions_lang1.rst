Transactions are formed using the methods ``startTransaction``, ``cancelTransaction``, and ``commitTransaction`` of a connection object. 
A connection object may obtained from any table object.

For example, the following code inserts matching entries for the master table ``Session`` and its part table ``SessionExperimenter``.

.. code-block:: matlab

    % get the connection object 
    session = Session
    connection = session.conn

    % insert Session and Session.Experimenter entries in a transaction
    connection.startTransaction
    try 
        key.subject_id = animal_id; 
        key.session_time = session_time;

        session_entry = key;
        session_entry.brain_region = region;
        insert(Session, session_entry) 

        experimenter_entry = key;
        experimenter_entry.experimenter = username;
        insert(SessionExperimenter, experiment_entry)
        connection.commitTransaction
    catch 
        connection.cancelTransaction
    end
        
      
Here, to external observers, both inserts will take effect together only upon exiting from the ``try-catch`` block or will not have any effect at all.
For example, if the second insert fails due to an error, the first insert will be rolled back. 

