DataJoint for MATLAB is a high-level programming interface for relational databases designed to support data processing chains in science labs. DataJoint is built on the foundation of the relational data model and prescribes a consistent method for organizing, populating, and querying data.

DataJoint was initially developed in 2009 by Dimitri Yatsenko in [Andreas Tolias' Lab](http://toliaslab.org) for the distributed processing and management of large volumes of data streaming from regular experiments. Starting in 2011, DataJoint has been available as an open-source project adopted by other labs and improved through contributions from several developers.


Running Tests Locally
=====================


* Create an `.env` with desired development environment values e.g.
``` sh
MATLAB_USER=raphael
MATLAB_LICENSE="#\ BEGIN----...---------END" # For image usage instructions see https://github.com/guzman-raphael/matlab, https://hub.docker.com/r/raphaelguzman/matlab
MATLAB_VERSION=R2018b
MATLAB_HOSTID=XX:XX:XX:XX:XX:XX
MATLAB_UID=1000
MATLAB_GID=1000
MYSQL_TAG=5.7
```
* `cp local-docker-compose.yml docker-compose.yml`
* `docker-compose up` (Note configured `JUPYTER_PASSWORD`)
* Select a means of running MATLAB e.g. Jupyter Notebook, GUI, or Terminal (see bottom)
* Run desired tests. Some examples are as follows:

| Use Case                     | MATLAB Code                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------ |
| Run all tests                | `run(tests.Main)`                                                              |
| Run one class of tests       | `run(tests.TestTls)`                                                           |
| Run one specific test        | `runtests('tests.TestTls/testInsecureConn')`                                   |
| Run tests based on test name | `import matlab.unittest.TestSuite;`<br>`import matlab.unittest.selectors.HasName;`<br>`import matlab.unittest.constraints.ContainsSubstring;`<br>`suite = TestSuite.fromClass(?tests.Main, ... `<br><code>&nbsp;&nbsp;&nbsp;&nbsp;</code>`HasName(ContainsSubstring('Conn')));`<br>`run(suite)`|


Launch Jupyter Notebook
-----------------------
* Navigate to `localhost:8888`
* Input Jupyter password
* Launch a notebook i.e. `New > MATLAB`


Launch MATLAB GUI (supports remote interactive debugger)
--------------------------------------------------------
* Shell into `datajoint-matlab_app_1` i.e. `docker exec -it datajoint-matlab_app_1 bash`
* Launch Matlab by runnning command `matlab`


Launch MATLAB Terminal
----------------------
* Shell into `datajoint-matlab_app_1` i.e. `docker exec -it datajoint-matlab_app_1 bash`
* Launch Matlab with no GUI by runnning command `matlab -nodisplay`