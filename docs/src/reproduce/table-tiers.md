# Table Tiers

To define a DataJoint table in Matlab:

1.  Define the table via multi-line comment.
2.  Define a class inheriting from the appropriate DataJoint class:
   `dj.Lookup`, `dj.Manual`, `dj.Imported` or `dj.Computed`.

## Manual Tables

The following code defines two manual tables, `Animal` and `Session`:

File `+experiment/Animal.m`

``` matlab
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
```

File `+experiment/Session.m`

``` matlab
%{
  # Experiment Session
  -> experiment.Animal
  session  : smallint  # session number for the animal
  ---
  session_date : date  # YYYY-MM-DD
  session_start_time  : float     # seconds relative to session_datetime
  session_end_time    : float     # seconds relative to session_datetime
  -> [nullable] experiment.User
%}
classdef Session < dj.Manual
end
```

Note that the notation to permit null entries differs for attributes versus foreign
key references.

## Lookup Tables

Lookup tables are commonly populated from their `contents` property. 

The table below is declared as a lookup table with its contents property
provided to generate entities.

File `+lab/User.m`

```matlab
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
```

## Imported and Computed Tables

Imported and Computed tables provide [`make` methods](./make-method) to determine how
they are populated, either from files or other tables.

Imagine that there is a table `test.Image` that contains 2D grayscale images in its
`image` attribute. We can define the Computed table, `test.FilteredImage` that filters
the image in some way and saves the result in its `filtered_image` attribute.

```matlab
%{ Filtered image
-> test.Image
---
filtered_image : longblob
%}

classdef FilteredImage < dj.Computed
    methods(Access=protected)
        function makeTuples(self, key)
            img = fetch1(test.Image & key, 'image');
            key.filtered_image = my_filter(img);
            self.insert(key)
        end
    end
end
```

??? Note "`makeTuples` vs. `make`"

    Currently matlab uses `makeTuples` rather than `make`. This will be
    fixed in an upcoming release. You can monitor the discussion
    [here](https://github.com/datajoint/datajoint-matlab/issues/141)

## Part Tables

The following code defines a Imported table with an associated part table. In MATLAB,
the master and part tables are declared in a separate `classdef` file. The name of the
part table must begin with the name of the master table. The part table must declare the
property `master` containing an object of the master.

`+image/Scan.m`

``` matlab
%{
    # Two-photon imaging scan
    -> Session
    scan : smallint  # scan number within the session
    ---
    -> Lens
    laser_wavelength : decimal(5,1)  # um
    laser_power      : decimal(4,1)  # mW
%}
classdef Scan < dj.Computed
    methods(Access=protected)
        function make(self, key)
            self.insert(key)
            make(image.ScanField, key)
        end
    end
end
```

`+image/ScanField.m`

``` matlab
%{
# Region of interest resulting from segmentation
-> image.Scan
mask            : smallint
---
ROI             : longblob  # Region of interest
%}

classdef ScanField < dj.Part
    properties(SetAccess=protected)
        master = image.Scan
    end
    methods
        function make(self, key)
            ...
            self.insert(entity)
        end
    end
end
```
