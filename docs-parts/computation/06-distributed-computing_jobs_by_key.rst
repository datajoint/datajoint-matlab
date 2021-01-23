
This can be done by using `dj.internal.hash` to convert the key as follows:

.. code-block:: matlab

    > kh = dj.internal.hash(key);
    > Lab.Jobs() & struct('key_hash', kh(1:32))


    ans = 


    Object Lab.Jobs

     :: the job reservation table for +Lab ::

              TABLE_NAME                         KEY_HASH                     status       error_message      user        host          pid        connection_id           timestamp              key        error_stack
        _______________________    ____________________________________    ____________    _____________    ________    _________    __________    _____________    _______________________    __________    ___________

        {'Lab.SessionAnalysis'}    {'jA9sN_5PvusWwmznLGcAZbTn5pGtba-z'}    {'error'}     {0×0 char}      {'datajoint@localhost'}    {'localhost'}    6.5356e+05        1919         {'2021-01-22 23:50:07'}    {'=BLOB='}    {'=BLOB='} 

    1 tuples (0.127 s)

    > del(Lab.Jobs() & struct('key_hash', kh(1:32)));

    > Lab.Jobs() & struct('key_hash', kh(1:32))

    ans = 


    Object Lab.Jobs

     :: the job reservation table for +Lab ::

    0 tuples (0.0309 s)

