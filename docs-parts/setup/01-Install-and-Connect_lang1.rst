
1. Download the DataJoint MATLAB Toolbox from the `MATLAB Central FileExchange <https://www.mathworks.com/matlabcentral/fileexchange/63218-datajoint>`_.
2. Open ``DataJoint.mltbx`` and follow installation instructions.
3. After installation, verify from MATLAB that you have the latest version of DataJoint (3.0.0 or above):
   ::

     >> dj.version
     DataJoint version 3.0.0
4. At the MATLAB command prompt, assign the environment variables with the database credentials.
   For example, if you are connection to the server ``alicelab.datajoint.io`` with username ``alice`` and password ``haha not my real password``, execute the following commands:
   ::

     setenv DJ_USER alice
     setenv DJ_HOST alicelab.datajoint.io
     setenv DJ_PASS 'haha not my real password'

You will need to execute these commands at the beginning of each DataJoint work session.
To automate this process, you might like to use the `startup.m <https://www.mathworks.com/help/matlab/ref/startup.html>`_ script.

However, be careful not to share this file or commit it to a public directory (a common mistake), as it contains a your login credentials in plain text.
If you are not sure, it is better not to set ``DJ_PASS``, in which case DataJoint will prompt to enter the password when connecting to the database.

To change the database password, use the following command

::

    >> dj.setPassword('my#cool!new*psswrd')

And update your credentials in your startup script for the next session.
