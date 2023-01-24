# Existing Pipelines

This section describes how to work with database schemas without access to the original
code that generated the schema. These situations often arise when the database is
created by another user who has not shared the generating code yet or when the database
schema is created from a programming language other than Matlab.

## Creating a virtual class

DataJoint MATLAB creates a `TableAccessor` property in each schema object. The
`TableAccessor` property, a *virtual class generator*, is available as `schema.v`, and
allows listing and querying of the tables defined on the server without needing to
create the MATLAB table definitions locally. For example, creating a scratch
`experiment` schema package and querying an existing `my_experiment.Session` table on
the server can be done as follows:

``` matlab
dj.createSchema('experiment', '/scratch', 'my_experiment')
addpath('/scratch')
experiment_schema = experiment.getSchema();
experiment_schema.v.Session() & 'session_id=1234';
```

???+ Note

    You can view the available tables in a schema by using tab completion on
    the `schema.v` property.

To visualize an unfamiliar schema, see commands for generating [diagrams](../../getting-started/#diagram).
