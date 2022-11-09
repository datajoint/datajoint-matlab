# Operators

The examples below will use the table definitions in [table tiers](../../reproduce/table-tiers).

<!-- ## Join appears here in the general docs -->

## Restriction

`&` and `-` operators permit restriction.

### By a mapping

For a [Session table](../../reproduce/table-tiers#manual-tables), that has the attribute
`session_date`, we can restrict to sessions from January 1st, 2022:

```matlab
Session & struct('session_date', '2018-01-01')
```

If there were any typos (e.g., using `sess_date` instead of `session_date`), our query
will return all of the entities of `Session`.

### By a string

Conditions may include arithmetic operations, functions, range tests, etc. Restriction
of table `A` by a string containing an attribute not found in table `A` produces an
error.

```matlab
Session & 'user = "Alice"' % (1)
Session & 'session_date >= "2022-01-01"' % (2)
```

1. All the sessions performed by Alice
2. All of the sessions on or after January 1st, 2022

### By a collection

When `cond` is a collection of conditions, the conditions are applied by logical
disjunction (logical OR). Restricting a table by a collection will return all entities
that meet *any* of the conditions in the collection. 

For example, if we restrict the `Session` table by a collection containing two
conditions, one for user and one for date, the query will return any sessions with a
matching user *or* date.

```matlab
cond_cell = {'user = "Alice"', 'session_date = "2022-01-01"'} % (1)
cond_struct = struct('user', 'Alice', 'session_date', '2022-01-01') % (2)
cond_struct(2) = struct('user', 'Jerry', 'session_date', '2022-01-01')

Session() & cond_struct % (3)
```

1. A cell array
2. A structure array
3. This command will show all the sessions that either Alice or Jerry conducted on the
   given day.

### By a query

Restriction by a query object is a generalization of restriction by a table. The example
below creates a query object corresponding to all the users named Alice. The `Session`
table is then restricted by the query object, returning all the sessions performed by
Alice. The `Experiment` table is then restricted by the query object, returning all the
experiments that are part of sessions performed by Alice.

``` matlab
query = Session & 'user = "Alice"'
Experiment & query
```

## Proj

Renaming an attribute in python can be done via keyword arguments: 

```matlab
table('old_attr->new_attr')
```

This can be done in the context of a table definition:

``` matlab
%{
  # Experiment Session
  -> experiment.Animal
  session  : smallint  # session number for the animal
  ---
  session_date : date  # YYYY-MM-DD
  session_start_time  : float     # seconds relative to session_datetime
  session_end_time    : float     # seconds relative to session_datetime
  -> User.proj(experimenter='username')
  -> User.proj(supervisor='username')
%}
classdef Session < dj.Manual
end
```

Or as part of a query

```matlab
Session * Session.proj('session->other')
```

Projection can also be used to to compute new attributes from existing ones.

```matlab
Session.proj('session_end_time-session_start_time -> duration') & 'duration > 10'
```

## Aggr

For more complicated calculations, we can use aggregation.

```matlab
Subject.aggr(Session,'count(*)->n') % (1)
Subject.aggr(Session,'avg(session_start_time)->average_start') % (2)
```

1. Number of sessions per subject.
2. Average `session_start_time` for each subject

<!-- ## Union appears here in the general docs -->

## Universal set

!!! Warning 

    `dj.U` is not yet implemented in MATLAB. The feature will be added in an
    upcoming release. You can track progress with 
    [this GitHub issue](https://github.com/datajoint/datajoint-matlab/issues/144).

Universal sets offer the complete list of combinations of attributes.

```matlab
dj.U('laser_wavelength', 'laser_power') & Scan % (1)
dj.U('laser_wavelength', 'laser_power').aggr(Scan, 'count(*)->n') % (2)
dj.U().aggr(Session, 'max(session)->n') % (3)
```

1. All combinations of wavelength and power.
2. Total number of scans for each combination.
3. Largest session number.

`dj.U()`, as shown in the last example above, is often useful for integer IDs.
For an example of this process, see the source code for 
[Element Array Electrophysiology's `insert_new_params`](https://datajoint.com/docs/elements/element-array-ephys/latest/api/element_array_ephys/ephys_acute/#element_array_ephys.ephys_acute.ClusteringParamSet.insert_new_params).
