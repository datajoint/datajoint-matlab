
This can be done by using `dj.internal.hash` to convert the key as follows:

.. code-block:: matlab

    > job_key = struct('table_name', 'Lab.SessionAnalysis', ...
                       'key_hash', dj.key_hash(key));
    > Lab.Jobs() & job_key


    ans = 


    Object Lab.Jobs

     :: the job reservation table for +Lab ::

              TABLE_NAME                         KEY_HASH                     status       error_message      user        host          pid        connection_id           timestamp              key        error_stack
        _______________________    ____________________________________    ____________    _____________    ________    _________    __________    _____________    _______________________    __________    ___________

        {'Lab.SessionAnalysis'}    {'jA9sN_5PvusWwmznLGcAZbTn5pGtba-z'}    {'error'}     {0×0 char}      {'datajoint@localhost'}    {'localhost'}    6.5356e+05        1919         {'2021-01-22 23:50:07'}    {'=BLOB='}    {'=BLOB='} 

    1 tuples (0.127 s)

    > del(Lab.Jobs() & job_key;

    > Lab.Jobs() & job_key

    ans = 


    Object Lab.Jobs

     :: the job reservation table for +Lab ::

    0 tuples (0.0309 s)

