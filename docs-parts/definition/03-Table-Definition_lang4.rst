
Furthermore, DataJoint provides the ``syncDef`` method to update the ``classdef`` file definition string for the table with the definition in the actual table:

.. code-block:: matlab

	syncDef(lab.User)    % updates the table definition in file +lab/User.m
