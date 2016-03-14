SnactiveRecord ORM
----------

SnactiveRecord's object relational mapping is similar to Rail's ActiveRecord, converting tables in a Postgres database into instances of `SnactiveRecord::SQLObject` class.

`SnactiveRecord::SQLObject` is a lightweight ORM, that features base CRUD methods and associations, without additional overhead.  Additionally, through its setup it reduces the number of necessary database queries further reducing overhead.

###All your CRUD methods are available to you, including:
* `#create`
* `#find`
* `#all`
* `#update`
* `#destroy`

###Builds out table associations, including:
* `::belongs_to`
* `::has_many`
* `::has_one_through`
* `::has_many_through`

##`SnactiveRecord::SQLRelation`
Allows for the ordering and searching of the database with minimal querying of the database.  This is possible through lazy, stackable methods.  The queries are only fired on `Snactive::SQLRelation#load` or when it is coerced into an Array.

###Methods include:
* `::all`
* `::where`
* `::includes`
* `::find`
* `::order`
* `::limit`
* `::count`
* `::first`
* `::last`

###Make use of Eager Loading to Reduce Queries
Preload associations by calling `SnactiveRecord::SQLRelation#includes`
Reduces queries from (n + 1) to 2.
