
DataJoint provides the interactive script ``dj.new`` for creating a new table.
It will prompt to enter the new table's class name in the form ``package.ClassName``.
This will create the file ``+package/ClassName.m``.

For example, define the table ``experiment.Person``

.. code-block:: matlab

	>> dj.new
	Enter <package>.<ClassName>: experiment.Person

	Choose table tier:
	  L=lookup
	  M=manual
	  I=imported
	  C=computed
	  P=part
	 (L/M/I/C/P) > M

This will create the file ``+experiment/Person.m`` with the following contents:

.. code-block:: matlab

	%{
	# my newest table
	# add primary key here
	-----
	# add additional attributes
	%}

	classdef Person < dj.Manual
	end

While ``dj.new`` adds a little bit of convenience, some users may create the classes from scratch manually.

Each newly created class must inherit from the DataJoint class corresponding to the correct :ref:`data tier <tiers>`: ``dj.Lookup``, ``dj.Manual``, ``dj.Imported`` or ``dj.Computed``.

The most important part of the table definition is the comment preceding the ``classdef``.
DataJoint will parse this comment to define the table.

The class will become usable after you edit this comment as described in :ref:`definitions`.
