[![View DataJoint on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/63218-datajoint)

# Welcome to DataJoint for MATLAB!
DataJoint for MATLAB is a high-level programming interface for relational databases designed to support data processing chains in science labs. DataJoint is built on the foundation of the relational data model and prescribes a consistent method for organizing, populating, and querying data.

DataJoint was initially developed in 2009 by Dimitri Yatsenko in Andreas Tolias' Lab at Baylor College of Medicine for the distributed processing and management of large volumes of data streaming from regular experiments. Starting in 2011, DataJoint has been available as an open-source project adopted by other labs and improved through contributions from several developers.
Presently, the primary developer of DataJoint open-source software is the company DataJoint (https://datajoint.com). Related resources are listed at https://datajoint.org.

## Installation
<details>
<summary>Click to expand details</summary>

### (Recommended) Greater than R2016b

1. Utilize MATLAB built-in GUI i.e. *Top Ribbon -> Add-Ons -> Get Add-Ons*
2. Search and Select `DataJoint`
3. Select *Add from GitHub*

### Using GHToolbox (FileExchange Community Toolbox)

1. Install *GHToolbox* using using an appropriate method in https://github.com/datajoint/GHToolbox
2. run: `ghtb.install('datajoint/datajoint-matlab')`

### Less than R2016b

1. Utilize MATLAB built-in GUI i.e. *Top Ribbon -> Add-Ons -> Get Add-Ons*
2. Search and Select `DataJoint`
3. Select *Download from GitHub*
4. Save `DataJoint.mltbx` locally
5. Navigate in MATLAB tree browser to saved toolbox file
6. Right-Click and Select *Install*
7. Select *Install*

### From Source

1. Download `DataJoint.mltbx` locally
2. Navigate in MATLAB tree browser to saved toolbox file
3. Right-Click and Select *Install*
4. Select *Install*

</details>

## Config
For help in utilizing `dj.config` (added in `3.4.0`), you may access the help via `help('dj.config')` or review it online [here](https://github.com/datajoint/datajoint-matlab/blob/c2bd6b3e195dfeef773d4e12bad5573c461193b0/%2Bdj/config.m#L2-L27). Formal documentation to follow.

## Documentation and Tutorials

* https://datajoint.org  -- start page
* https://docs.datajoint.org -- up-to-date documentation
* https://tutorials.datajoint.io -- step-by-step tutorials
* https://elements.datajoint.org -- catalog of example pipelines
* https://codebook.datajoint.io -- interactive online tutorials

## Citation
+ If your work uses DataJoint for MATLAB, please cite the following Research Resource Identifier (RRID) and manuscript.

+ DataJoint ([RRID:SCR_014543](https://scicrunch.org/resolver/SCR_014543)) - DataJoint for MATLAB (version `<Enter version number>`)

+ Yatsenko D, Reimer J, Ecker AS, Walker EY, Sinz F, Berens P, Hoenselaar A, Cotton RJ, Siapas AS, Tolias AS. DataJoint: managing big scientific data using MATLAB or Python. bioRxiv. 2015 Jan 1:031658. doi: https://doi.org/10.1101/031658

## Running Tests Locally
<details>
<summary>Click to expand details</summary>

* Create an `.env` with desired development environment values e.g.
``` sh
MATLAB_USER=rguzman
MATLAB_LICENSE=IyBCRUd... # For image usage instructions see https://github.com/guzman-raphael/matlab, https://hub.docker.com/r/raphaelguzman/matlab
MATLAB_VERSION=R2019a
MATLAB_HOSTID=XX:XX:XX:XX:XX:XX
MATLAB_UID=1000
MATLAB_GID=1000
MYSQL_TAG=5.7
MINIO_VER=RELEASE.2022-01-03T18-22-58Z
```
* `cp local-docker-compose.yaml docker-compose.yaml`
* `docker-compose up` (Note configured `JUPYTER_PASSWORD`)
* Select a means of running MATLAB e.g. Jupyter Notebook, GUI, or Terminal (see bottom)
* Add `tests` directory to path e.g. in MATLAB, `addpath('tests')`
* Run desired tests. Some examples are as follows:

| Use Case                     | MATLAB Code                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------ |
| Run all tests                | `run(Main)`                                                              |
| Run one class of tests       | `run(TestTls)`                                                           |
| Run one specific test        | `runtests('TestTls/TestTls_testInsecureConn')`                                   |
| Run tests based on test name | `import matlab.unittest.TestSuite;`<br>`import matlab.unittest.selectors.HasName;`<br>`import matlab.unittest.constraints.ContainsSubstring;`<br>`suite = TestSuite.fromClass(?Main, ... `<br><code>&nbsp;&nbsp;&nbsp;&nbsp;</code>`HasName(ContainsSubstring('Conn')));`<br>`run(suite)`|


### Launch Jupyter Notebook

* Navigate to `localhost:8888`
* Input Jupyter password
* Launch a notebook i.e. `New > MATLAB`


### Launch MATLAB GUI (supports remote interactive debugger)

* Shell into `datajoint-matlab_app_1` i.e. `docker exec -it datajoint-matlab_app_1 bash`
* Launch Matlab by runnning command `matlab`


### Launch MATLAB Terminal

* Shell into `datajoint-matlab_app_1` i.e. `docker exec -it datajoint-matlab_app_1 bash`
* Launch Matlab with no GUI by runnning command `matlab -nodisplay`

</details>