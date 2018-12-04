
.. warning::
  This section documents future intended behavior in MATLAB, which is contrary to current behavior.
  DataJoint for MATLAB has an open `issue <https://github.com/datajoint/datajoint-matlab/issues/128>`_ tracking this change.

A collection can be a cell array or structure array.
Cell arrays can contain collections of arbitrary restriction conditions.
Structure arrays are limited to collections of mappings, each having the same attributes.

.. code-block:: matlab

    % a cell aray:
    cond_cell = {'first_name = "Aaron"', 'last_name = "Aaronson"'}

    % a structure array:
    cond_struct = struct('first_name', 'Aaron', 'last_name', 'Paul')
    cond_struct(2) = struct('first_name', 'Rosie', 'last_name', 'Aaronson')
