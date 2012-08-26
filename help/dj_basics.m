%% Basic concepts 
%
%% The relational data model
% Invented by IBM researcher <matlab:web('http://en.wikipedia.org/wiki/Edgar_F._Codd','-browser') Edgar F. Codd> in 1969, 
% (E. F. Codd. "A relational model of data for large shared data banks." _Communications of the ACM_, 13(*6*):387, 1970) 
% the <matlab:web('http://en.wikipedia.org/wiki/Relational_model','-browser') relational data model> for databases steadily 
% replaced the earlier hierarchical and network models and has become the de facto standard for mainstream databases today, 
% supporting banking transactions, airfare bookings, and data-intensive websites such as Facebook, Wikipedia, and YouTube, 
% to pick but a few examples.  Modern relational database management systems execute fast, precise, and flexible data 
% queries and preclude inconsistencies arising from simultaneous or interrupted manipulations by multiple users. 
% Interactions with a relational database are performed in a query language such as <matlab:web('http://en.wikipedia.org/wiki/SQL','-browser') SQL>. 
%
%% Attributes and tuples 
% A tuple is a set of attribute name/value pairs. For example, the tuple
%
%  mouse_id      measure_date      weight 
%    1001          2010-10-10       21.5 
%
% in a given relation may represent a real-world fact such as "On Oct. 10, 2010, mouse #1001 weighed 21.5 grams."  
% An attribute name is more than just a name: it implies a particular _datatype_ (domain) and a unique _role_ in the tuple and in the external world.  
% Thus attribute names must be unique in a tuple and their order in the tuple is not significant.  
%
% The closest equivalent of a tuple in Matlab is a structure. We will use the terms _attribute_ and _field_ interchangeably.
%
%% Relations
% A relation is a set of tuples that share the same set of attribute names. No duplicate tuples can exist in a relation.  The ordering of tuples in a relation is not significant.  
%
%% Relvars
% A relvar (relation variable) is a variable specifying a relation. It is distinguished from the relation itself due to the fact that, 
% even if a relvar remains unchanged, its corresponding  relation may be changed by other transactions elsewhere.
% 
% Starting with a _base relvar_ expressing the complete contents of a given  _table_ in the database, we can transform them into _derived relations_ by applying _relational operators_ until they contain only all the necessary information, and then retrieve their values into the MATLAB workspace.  We will use the term _table_ and _base relvar_ interchangeably. 
%
%% Matching tuples
% The key concept at the foundation of data manipulations in the relational model is _tuple matching_.  Two tuples match if their identically named attributes contain equal values.  
%
% Thus one tuple may be used to address a group of  other matching tuples in a relation (e.g. see [[restrict, semijoin, antijoin, and union]]). Two tuples may be merged into one if they match, but not otherwise. The _join_ of two relations is the set of all possible merged pairs from the two original relations.
%
%% Primary keys
% In DataJoint, each relation has one _primary key_ comprising a subset of its attributes that are designated to uniquely identify any tuple in the relation. No two tuples in the same relation can have the same combination of values in their primary key fields.  To uniquely identify a tuple in the relation, one must provide the values of the primary key fields as a matching tuple.
%
% Learn more in <primary_keys.html primary keys>.
%
%% Foreign keys
% A base relation may have one or more _foreign keys_, i.e. a subset of its attributes that correspond to the primary key of another, _referenced_ base relation. The database will enforce _referential constraints_: a base relation cannot contain a tuple whose foreign key value does not match the primary key value of a tuple in the referenced relation. 
%
% Learn more in <foreign_keys.html foreign keys>
%
% _Copyright 2012  Dimitri Yatsenko_
 