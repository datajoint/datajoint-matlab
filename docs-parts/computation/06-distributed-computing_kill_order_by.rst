
For example, to sort the output by hostname in descending order:

.. code-block:: matlab


    dj.kill('', dj.conn, 'host desc');
    
      ID   USER   HOST        DB   COMMAND   TIME   STATE   INFO   TIME_MS   ROWS_SENT   ROWS_EXAMINED 
     +--+ +----+ +---------+ +--+ +-------+ +----+ +-----+ +----+ +-------+ +---------+ +-------------+
      35   cat    localhost:38772   Sleep     94                    94040     0           0             
      36   cat    localhost:36543   Sleep     68                    68421     1           0             
    
    process to kill ('q'-quit, 'a'-all) > q
