``+test/Mouse.m``

.. code-block:: matlab

  %{
  mouse_name : varchar(64)
  ---
  mouse_dob : datetime
  %}

  classdef Mouse < dj.Manual
  end

``+test/SubjectGroup.m``

.. code-block:: matlab

  %{
  group_number : int
  ---
  group_name : varchar(64)
  %}

  classdef SubjectGroup < dj.Manual
  end

``+test/SubjectGroupGroupMember.m``

.. code-block:: matlab

  %{
  -> test.SubjectGroup
  -> test.Mouse
  %}

  classdef SubjectGroupGroupMember < dj.Part
  end
