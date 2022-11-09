# Make Method

Consider the following table definition from the article on 
[table tiers](../table-tiers):

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

The `FilteredImage` table can be populated as

``` matlab
populate(test.FilteredImage)
```

Note that it is not necessary to specify which data needs to be computed. DataJoint will
call `make`, one-by-one, for every key in `Image` for which `FilteredImage` has not yet
been computed.

The `make` method receives one argument: the dict `key` containing the primary key value
of an element of `key source` to be worked on. 

## Optional Arguments

Behavior of the `populate` method depends on the number of output arguments requested in
the function call. When no output arguments are requested, errors will halt population.
With two output arguments(`failedKeys` and `errors`), `populate` will catch any
encountered errors and return them along with the offending keys.

## Progress

The function `parpopulate` works identically to `populate` except that it uses a job
reservation mechanism to allow multiple processes to populate the same table in
parallel without collision. When running `parpopulate` for the first time, DataJoint
will create a job reservation table and its class `<package>.Jobs` with the following
declaration:

``` matlab
{%
  # the job reservation table
  table_name      : varchar(255)          # className of the table
  key_hash        : char(32)              # key hash
  ---
  status            : enum('reserved','error','ignore')# if tuple is missing, the job is available
  key=null          : blob                  # structure containing the key
  error_message=""  : varchar(1023)         # error message returned if failed
  error_stack=null  : blob                  # error stack if failed
  host=""           : varchar(255)          # system hostname
  pid=0             : int unsigned          # system process id
  timestamp=CURRENT_TIMESTAMP : timestamp    # automatic timestamp
%}
```

A job is considered to be available when `<package>.Jobs` contains no matching entry.

For each `make` call, `parpopulate` sets the job status to `reserved`. When the job is
completed, the record is removed. If the job results in error, the job record is left
in place with the status set to `error` and the error message and error stacks saved.
Consequently, jobs that ended in error during the last execution will not be attempted
again until you delete the corresponding entities from `<package>.Jobs`.

The primary key of the jobs table comprises the name of the class and a 32-character
hash of the job's primary key. However, the key is saved in a separate field for error
debugging purposes.
