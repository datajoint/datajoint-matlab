
File ``+experiment/Animal.m``

.. code-block:: matlab

    %{
      # information about animal
      animal_id : int  # animal id assigned by the lab
      ---
      -> experiment.Species
      date_of_birth=null : date  # YYYY-MM-DD optional
      sex='' : enum('M', 'F', '')   # leave empty if unspecified
    %}
    classdef Animal < dj.Manual
    end

File ``+experiment/Session.m``

.. code-block:: matlab

    %{
      # Experiment Session
      -> experiment.Animal
      session  : smallint  # session number for the animal
      ---
      session_date : date  # YYYY-MM-DD
      -> experiment.User
      -> experiment.Anesthesia
      -> experiment.Rig
    %}
    classdef Session < dj.Manual
    end

File ``+experiment/Scan.m``

.. code-block:: matlab

    %{
      # Two-photon imaging scan
      -> experiment.Session
      scan : smallint  # scan number within the session
      ---
      -> experiment.Lens
      laser_wavelength : decimal(5,1)  # um
      laser_power      : decimal(4,1)  # mW
    %}
    classdef Scan < dj.Manual
    end
