``+test/Mouse.m``

.. code-block:: matlab

  %{
  mouse_name : varchar(64)
  ---
  mouse_dob : datetime
  %}

  classdef Mouse < dj.Manual
  end

``+test/MouseDeath.m``

.. code-block:: matlab

  %{
  -> test.Mouse
  ---
  death_date : datetime
  %}

  classdef MouseDeath < dj.Manual
  end
