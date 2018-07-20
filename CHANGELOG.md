Shark Changelog
===============
## v2.3.xx - July 20, 2018

This version addresses some beta test issues withthe SharkSync.io platofrm, as well as improving documentation for the ORM.  All documentation is now solely focused towards Swift 4, examples will no longer be provided for objective-c.

## v2.2.xx - July 18, 2018

After a year of attempting to port the entire product into Swift 3 then 4 then 4.1, we have come to the conclusion that at this precise time it is just not possible.  Instead we have decided to make the interaction between the two languages as smooth and as nice as possible.  So we have strongly typed all methods and properties wherever possible and added extra functionality to data objects to allow a smoother code flow.  It is a shame we wasted over a year, but it became apparent that the "little bugs" were just escalating out of control and there were far too many compromises that would have resulted in a significantly different product, that was not as fluid to use.

+ (change) Added 'settings' property on SharkORM to allow developers to directly change the settings without having to implement the delegate method and return a settings object.
+ (change) Made SRKIndexDefinition methods return the object again, allowing nested property creation all on a single line.  Example:
```Swift
return SRKIndexDefinition().add("name", order: SRKIndexSortOrderAscending).add("age", order: SRKIndexSortOrderDescending)
```
+ (change) Added a convenience `init` to SRKIndexDefinition to allow you to just create an index with the properties you want and return it.  Example:
```Swift
return SRKIndexDefinition(["name","age"])
```
+ (change) Improved interface to queries. Added `first` method to allow you to get only the first object in the result set.
+ (change) added `clone` to create a new object with all of the property values copied across
+ (change) added `asDictionary` method to export an object as a dictionary to make interfacing with network calls far easier.
+ (improvement) Implemented a SchemaManager class, which solves the race condition when opening up SRKObjects before the database has even been opened.  Which then means that the entities are no longer refactored.

## SharkSync.io

SharkSync.io is the new code-less data synchronisation platform from the SharkORM team.  The design principal behind the service is to require minimal effort from developers, removing the complication of delivering an online/offline experience whilst minimising data collisions.  With a flexible security/visibility model allowing the partitioning of data on a record by record basis across all tables.  Which makes for a flexible and unique way to specify which clients have access to which data.

All data is encrypted and decrypted on the device, we have zero access to the data at any point.  Developers can use our standard AES256 implementation and specify their own key.  Or they can override the encryption functions and use anything they choose instead.

To get started, create an account at SharkSync.io and get your initial block of free credits (1MM Tokens to get you started).   This is not a profit seeking service, and token cost and expenditure is matched to the cost of providing the service using AWSs', highly scalable, infrastructure.

The service is also Open Source, so you are welcome to self host.  But as the cost is the same it becomes a political choice at that point.  Also, in the spirit of being entirely fair you are able to download all of your data from our service and import it into a self hosted setup and simply point your application at a different endpoint.

## v2.1.3 - Mar 31, 2017

Release, no changes.  Trying to fix a jammed up Cocoapods repository.

## v2.1.2 - Mar 31, 2017

Changes to better support Swift3 interoperability.  Fixes all kinds of strange issues with the persistence of Arrays & Dictionaries coming back out as strings.

Added the ability to initialise an object with a dictionary, to make it easier to populate objects programatically from network calls.

Removed `databaseEntityWasDeleted`, `databaseEntityWasUpdated`, `databaseEntityWasInserted` from SRKDelegate, these have been replaced with .....

Added 3 methods to the SharkORM class to allow developers to register blocks with the ORM to support callbacks globally.  The new methods are,  `setInsertCallbackBlock`, `setUpdateCallbackBlock`, `setDeleteCallbackBlock`.  The block takes an SRKObject as a parameter, which you can inspect to see which type of object the event was raised for.

`.orderBy()` parameters can now be chained together, example: `.orderBy("name").orderBy("age")`.

Improved documentation for object methods, including excluding properties from the schema.

More unit tests added, stability improvements.

## v2.1.1 - Jan 4, 2017

Upgraded to SQLite v3.16.1.

Fixed a reported issue where the limits configured in SQLite were too low for SharkORM to operate in extreme circumstances.

## v2.1.0 - Jan 4, 2017

New transaction module, all changes made within a transaction block will be rolled back on error.  Including any modification of property values of referenced but uncommited objects, it is like the block never ran! (as far as the entities are concerned).  Transactions are now much faster, and there is a slightly lower memory impact.

Fixed a bug with persisting NSArray & NSDictionary objects within a transaction.

You may now manually fail a transaction by calling SRKFailTransaction() within the block, allowing developers to abort and rollback based on applicaiton logic.

UUID primary keys are now generated in lowercase.

Added *..commitOptions (property)*, which allows for far greated control over how SharkORM commits individual objects.  You can guess what most things do from the properties on the class (postCommitBlock,postRemoveBlock,ignoreEntities,commitChildObjects,resetOptionsAfterCommit,raiseErrors,triggerEvents).

Work on the Swift version has now officially started, hopefully resulting in an importable module very soon.

## v2.0.9 - Oct 19, 2016

Fixed a bug where the high velocity calls to the orm from dispatched blocks, which were inadvertantly accessing some static variables caused the main thread to block forever and would never release.

Upgraded to SQLite 3.15.0 - Took 3 seconds off our performance test, which is a 10k random read-write routine, across multiple tables with multiple record shapes and event trigers.  Was 15.03s now 11.98s.


## v2.0.8 - Aug 03, 2016
#### Added Object dot notation support to query syntax

Developers can now access the properties of related objects from within the *where* clause of a query, such as the following.  If we take the example of a Person class which is related to the Department class via the `department` property.
    
```swift
Person.query().whereWithFormat("department.name = %@", withParameters: ["Test Department"]).fetch()
```
Where `name` is within a related object, SharkORM will now automatically re-arrange the query and join the two tables on that relationship and therefore validate that condition.
    
Updated to SQLite v3.13.0

Better support of UUID primary keys in many scenarios.

Change [SRKResultSet removeAll] to return a BOOL value indicating the success of the operation to remain consistent with other read/write operations.


## v2.0.7 - July 24, 2016
Fixed a bug where the cached property types of an SRKObject did not contain a data type for the Id column.

## v2.0.6 - July 17, 2016
Fixed an issue with circular commit chains, SRKObjects can now be arranged with complicated relationships such as A-B-C-B.  But also with A-C as well, causing a quad point relationship within a single commit.

SRKObject’s now implement a class method ‘ignoreProperties’.  Which
allows developers to choose which properties to ignore.

## v2.0.5 - June 29, 2016
Fixed crash when printing an object without an primary key value.  No Null check was made.
Fixed serious issue, where SRKObject properties were being persisted. Causing query errors.

## v2.0.4 - June 24, 2016

Added support for Raw Queries, Inherritance support & Carthage support.

Raw query example:
```objective-c
SRKRawResults* results = [SharkORM rawQuery:@"SELECT * FROM Person ORDER BY age;"];
```

## v2.0.3 - June 20, 2016
Added more tests, changed print output of a class to output in the style of the following.
```
{
    entity = Person;
    joins =     {
    };
    "pk column" = Id;
    "pk value" = 36664;
    properties =     (
                {
            name = Id;
            type = number;
            value = 36664;
        },
                {
            name = payrollNumber;
            type = number;
            value = 0;
        },
                {
            name = age;
            type = number;
            value = 36;
        },
                {
            name = Name;
            type = unset;
            value = "<null>";
        },
                {
            name = location;
            type = unset;
            value = "<null>";
        },
                {
            name = department;
            type = unset;
            value = "<null>";
        },
                {
            name = seq;
            type = number;
            value = 0;
        }
    );
    relationships =     (
                {
            property = department;
            status = unloaded;
            target = Department;
        },
                {
            property = location;
            status = unloaded;
            target = Location;
        }
    );
}
```

## v2.0.2 - June 19, 2016
Updated the podspec, pushed a new version due to a problem merging a pull request

## v2.0.1 - June 18, 2016
JOIN: Added join tests & fixed bugs with join.
This turned up some faults when you wanted to Query C From A through a B join.  So, if you specifically specified the FQ field name it failed, because the ORM attemoted to prepend the self.class name.

Structure:
[Person]->[Deaprtment]->[Location]

Code example:
```objective-c
Person * p = [[[[[Person query]
                    joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Id"]
                     fetch]
               firstObject];
```


Fixed framework build output to include x86_64 in the available architectures

## v2.0.0 - June 16, 2016
Initial check in.  Replaces the DBAccess project from v1.6.13
