
File ``+lab/User.m``

.. code-block:: matlab

    %{
        # users in the lab
        username : varchar(20)   # user in the lab
        ---
        first_name  : varchar(20)   # user first name
        last_name   : varchar(20)   # user last name
    %}
    classdef User < dj.Lookup
        properties
            contents = {
                'cajal'  'Santiago' 'Cajal'
                'hubel'  'David'    'Hubel'
                'wiesel' 'Torsten'  'Wiesel'
            }
        end
    end
