
The table definition is contained in the first block comment in the class definition file.
Note that although it looks like a mere comment, the table definition is parsed by DataJoint.
This solution is thought to be convenient since MATLAB does not provide convenient syntax for multiline strings.

.. code-block:: matlab

	%{
	# database users
	username : varchar(20)   # unique user name
	---
	first_name : varchar(30)
	last_name  : varchar(30)
	role : enum('admin', 'contributor', 'viewer')
	%}
	classdef User < dj.Manual
	end
