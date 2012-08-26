%% Motivation
% DataJoint was developed by Dimitri Yatsenko in Andreas Tolias' lab at Baylor College of Medicine beginning in October 2009 to process massive amounts of data resulting from neuroscience experiments. For its logical rigor, DataJoint  is built on the foundation of [[the relational data model]]. DataJoint was inspired in part by an earlier database tool in the lab called Steinbruch developed by Alex Ecker and Philipp Berens. 
% 
% This page is written to help you decide if DataJoint is the right tool for your application.
% 
%% Designed for busy scientists
% DataJoint is designed to enable non-database programmers to organize their expansive data in the rigorous framework of the relational data model. All data definition and manipulation tasks are performed from MATLAB using MATLAB language constructs.
% 
% That said, even experienced database programmers may accelerate their development and improve their data organization using DataJoint.
% 
%% Object-relational mapping
% DataJoint associates each table in the database with a MATLAB class. Users manipulate data by invoking the MATLAB classes that encapsulate the corresponding tables. 
% 
%% Data compatibility 
% DataJoint stores data in regular MySQL tables which can be accessed from many other software and programming environments. Any other language that has a MySQL API can be adapted to exchange data with DataJoint applications.  For example, the project [DataJoint-python](https://github.com/dimitri-yatsenko/datajoint-python) replicates DataJoint functionality for the Python programming language. 
% 
%% Simplified relational algebra
% Many database languages that were originally intended to implement [[the relational data model]] have veered off course. A language like SQL enables relational concepts but hardly encourages them.  For example, the result of an SQL query can have unnamed fields or can have duplicate rows &mdash; which are both violations of relational concepts. SQL does not implement a useful relational algebra: a simple way to construct more complex expressions from simpler ones. As the result, SQL queries of any complexity quickly become cumbersome. 
% 
% With DataJoint, precise relational queries can be composed with ease.
% 
% For example, referring to the examples [[schema "common"]] and [[schema "two_photon"]], the DataJoint expression 
%
%  rel = common.TpSession & 'lens="25x"' & (common.TpScan - tp.Sync)
% 
% creates the relational variable `rel` which stands for "all the two-photon sessions using the 25&times; lens that have scans that have not been synchronized with the visual stimulus."  
% 
% The equivalent SQL code would read something like
%
%  SELECT * FROM `common`.`tp_session` 
%  WHERE lens="25x"  AND (`animal_id`,`tp_session`) IN (
%     SELECT `animal_id`,`tp_session` FROM `common`.`tp_scan` 
%     WHERE ((`animal_id`,`scan_idx`,`tp_session`) NOT IN (
%        SELECT `animal_id`,`scan_idx`,`tp_session` FROM `two_photon`.`_sync`)))
% 
% Furthermore, this query can be incrementally built from its subexpressions, each of which can be individually examined:
%
%   x25 = common.TpSession & 'lens="25x"'
%   noSync = common.TpScan - tp.Sync
%   rel = x25 & noSync
%
% Simply typing each expression at the MATLAB command prompt will display the first few rows from the query and their total count. Then the [fetch](fetching-data-into-the-MATLAB-workspace) command brings the data into the MATLAB workspace:
%
%   s = rel.fetch('*')
%  
%% Algebraic closure
% Algebraic closure means that the results of one expression can be used in another. This was illustrated in the simple example above. DataJoint has it whereas SQL does not.
% 
%% Simple table creation with well-designed referential constraints
% DataJoint provides its own syntax for creating tables directly from MATLAB code. The table definition is included as the first brace-percent comment of the table's `.m` file. Tables are created automatically upon the first invocation of the table in application code.
% 
% For example, the class [psy.Trial](https://github.com/dimitri-yatsenko/dj-schema-psy/blob/master/Trial.m) in the example [[schema "psy"]] contains the table definition describing visual stimulus trials:
%
%   %{
%   psy.Trial (manual) # visual stimulus trial
%   -> psy.Session
%   trial_idx       : int         # trial index within sessions
%   ---
%   -> psy.Condition
%   flip_times                  : mediumblob          # (s) row array of flip times
%   last_flip_count             : int unsigned        # the last flip number in this trial
%   trial_ts=CURRENT_TIMESTAMP  : timestamp           # automatic
%   %}
% 
% The corresponding MySQL command that DataJoint generates automatically upon the first use of the class `psy.Trial` is 
%
%  CREATE TABLE `trial` (
%   `animal_id` int(11) NOT NULL COMMENT 'id (internal to database)',
%   `psy_id` smallint(5) unsigned NOT NULL COMMENT 'unique psy session number',
%   `trial_idx` int(11) NOT NULL COMMENT 'trial index within sessions',
%   `cond_idx` smallint(5) unsigned NOT NULL,
%   `flip_times` mediumblob NOT NULL COMMENT '(s) row array of flip times',
%   `last_flip_count` int(10) unsigned NOT NULL COMMENT 'the last flip number in this trial',
%   `trial_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'automatic',
%   PRIMARY KEY (`animal_id`,`psy_id`,`trial_idx`),
%   KEY `animal_id` (`animal_id`,`psy_id`,`cond_idx`),
%   CONSTRAINT `trial_ibfk_1` FOREIGN KEY (`animal_id`, `psy_id`) 
%       REFERENCES `session` (`animal_id`, `psy_id`) ON UPDATE CASCADE,
%   CONSTRAINT `trial_ibfk_2` FOREIGN KEY (`animal_id`, `psy_id`, `cond_idx`) 
%       REFERENCES `condition` (`animal_id`, `psy_id`, `cond_idx`) ON UPDATE CASCADE
% ) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='visual stimulus trial' 
%  
%% Simple code sharing
% Since table definitions are included in the MATLAB `classdef` files, users only need to share the MATLAB files  to replicate the same functionality.
% 
%% Automated computations with referential integrity
% DataJoint implements a standard process for [[populating computed data]]. This process uses referential constraints to enforce all data dependencies. This processes also uses transactional processing to ensure  that interrupted computations do not result in partially computed invalid results.
% 
%% Support for distributed processing
% DataJoint provides a job reservations process to enable [[distributed processing]] on multiple processors or  computers without conflict.
% 
%% Cons: DataJoint is not a general-purpose interface
% DataJoint is designed for the sole purpose of providing a robust and intuitive data model for scientific data processing chains. As such it does not reproduce all the features and capabilities of SQL. To achieve its strict adherence to the relational data model, its expressive power and simplicity, DataJoint imposes some limitations and conventions. This is done intentionally to avoid dangerous usage of SQL and to make the data model logically sound.
% 
% Here are some examples of such conventions and limitations:
% 
% DataJoint does not allow updating an individual attribute value in a given tuple (SQL's UPDATE command): all data manipulations are done by inserting or deleting whole tuples. This is done for good reason since referential constraints ([[foreign keys]]) only enforce data dependencies between tuples but not between individual attributes.
% 
% DataJoint limits some operators to enforce clarity. For example, its projection operator does not allow projecting out any of the primary key attributes. This ensures that the result of the projection operator has the same cardinality as the original relation (the same number of rows). If the user really intends to produce a relation with a different primary key, she must explicitly declare such a relation in the form of a [base relvar](base relvars). Again, this is not a real limitation but a specific prescription of how things should be done in a uniform manner.
% 
% In DataJoint, all [[foreign keys]] between tables are formed between identically named fields. This convention allows easy specification of functional dependencies and easy relational [[join]] operators. It also allows to replace the many forms of the join operator in other language with a single natural [[join]] operator. In a large schema, this convention may lead to long composite [[primary keys]] in tables that are low in the dependency hierarchy, but MySQL handles these with ease.  This convention is particularly important in DataJoint because it allows tables across the database or multiple databases to be logically linked without having to follow the path of intermediate dependencies. 
% 
% Advanced users can circumvent DataJoint altogether and issue SQL queries directly from the MATLAB command prompt, e.g:
%   query(dj.conn, 'CREATE DATABASE electrophys')
% or through any other database interface.