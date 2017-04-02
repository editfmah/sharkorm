Shark ORM
============

Shark allows you to create a model layer in your iOS, macOS or tvOS app naturally, using simple and clean syntax.  Shark does as much of the heavy lifting for you, so you don't have to put unnecessary effort into dealing with your data objects.

Its mantra is simple, to be fast, simple and the first choice for any developer.

## Getting started

Shark is designed to get your app working quickly, integrated as source code, or as a framework. 

### Requirements
XCode 8+, iOS7+

### Install From Cocoapods

#### To install it, simply add the following line to your Podfile:
```ruby
pod "SharkORM"
```
### Install as Framework
Download the source code from GitHub and compile the SharkORM framework target, and then within your application, add the following:

```objective-c
// include the framework header within your app, for Swift add this to the bridging header
#include <SharkORM/SharkORM.h>
```
### Install as Source
Download the source code from GitHub and add to your target the contents of Core and SQLite:

```objective-c
// include the header within your app, for Swift add this to the bridging header
#include “SharkORM.h”
```

## Getting help and support
If you are having trouble with your implementation then simply ask a question on Stack Overflow, the team actively monitor SO and will answer your questions as quickly as possible.

If you have found a bug or want to suggest a feature, then feel free to use the issue tracker in GitHub to raise an issue.

## Usage

### Setting up your project

Once you have added the SharkORM framework into your application, you will need to start it as soon as possible in your application lifecycle.  SRKDelegate needs to be set as well, we recommend this is added to your application delegate.

```objective-c
// Objective-C
@interface AppDelegate : UIResponder <UIApplicationDelegate, SRKDelegate>
```
```swift
// Swift
class AppDelegate: UIResponder, UIApplicationDelegate, SRKDelegate
```
Then you need to start SharkORM early on:

```objective-c
// Objective-C
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [SharkORM setDelegate:self];
    [SharkORM openDatabaseNamed:@"myDatabase"];
    return YES;
}
```
```swift
// Swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
	
	SharkORM.setDelegate(self)
	SharkORM.openDatabaseNamed("myDatabase")
	
	return true
}
```
### Objects
SharkORM objects are normal classes with properties defined on them, the ORM then inspects all these classes and mirrors their structure in a SQLite database automatically. If you add or remove columns, then the tables are updated to represent the current structure of the classes.

You can use these classes in much the same way as any other class in the system, and they can be extended with methods and sub classed, and passed around from thread to thread with no problem.

In Objective-C properties need to be implemented using `@dynamic`, this is to indicate to the ORM that it will control the fetching and setting of these values from the database, and in Swift the property is implemented as `var dynamic`

## Schemas (Migration)
The schema is automatically maintained from the class signatures and all additions, deletions & type changes are automatically made to the database.  Where possible data is retained and converted between types.

If a default value is specified using, `defaultValuesForEntity` and a property is added, then the column is automatically populated with teh default value.

Tables are created automatically by referencing a class which is a subclass of SRKObject.

### Excluding properties from the schema.
By default all properties that are either `@dynamic` or `dynamic var` are picked up by SharkORM and added to the coresponding tables.  If you wish to exclude certain properties which are not for persistence then implement the class method `ignoredProperties`, for which you return an array of string values which match the properties you wish the ORM to ignore.

Example:

```objective-c
// Obj-C
+ (NSArray*)ignoredProperties {
   return @[@"age",@"name"];
}
```
```swift
// Swift
override class func ignoredProperties() -> [Any] {
   return ["age","name"]
}
```

#### Example Object
`Objective-C`
```objective-c
//  Header File : Person.h
#import "SharkORM.h"

@interface Person : SRKObject

@property NSString*         name;
@property int               age;
@property int               payrollNumber;

// to create a relationship, you add a property as another SRKObject class
@property Department*       department;

@end

// Source File : Person.m
#import "Person.h"

@implementation Person

@dynamic name,age,payrollNumber, department;

@end

```
`Swift`
```Swift

class Person: SRKObject {
	dynamic var name : String?
	dynamic var age : NSNumber?
	dynamic var payrollNumber : NSNumber?
	dynamic var department : Department?
}
```

### Initial values
You can initialise an SRKObject with a dictionary, allowing you to populate an object programatically.

Example:

```objective-c
// Obj-C
Person* p = [[Person alloc] initWithDictionary:@{@"Name":@"Adrian Herridge",@"age":@(38)}];
```
```swift
// Swift
let p = Person(dictionary: ["Name" : "Adrian Herridge", "age" : 38])
```


##Supported Types

Shark supports the following types: `BOOL`, `bool`, `int`, `int64`, `uint`, `uint64`, `float`, `double`, `long`, `long long`, `unsigned long long`, `NSString`, `NSDate`, `NSData`, `NSNumber`.

## Relationships

`SRKObject`s can be linked to each other either by directly embedding them to create a one-to-one relationship (`dynamic var department : Department?`) or for a one-to-many relationship we employ the use of a method which returns either an `NSArray` or `SRKResultSet` object.

With the Person object already defined, and with a property department let’s look at the Department class.

`Objective-C`
```objective-c
// Department.h
@interface Department : SRKObject
@property NSString*   	name;
@property Location*		location;
@end
```

`Swift`
```swift
class Department : SRKObject { 
    dynamic var name: String?
    dynamic var location: Location?
}
```

### One-to-One Relationships

This has been created by adding the `Department` property into the `SRKObject` class, and once it has been set with a value it can be used as any other property making use of object dot notation.

`Objective-C`
```objective-c
Person* employee = [Person new];
Department* section = [Department new];
employee.department = section; 
```
`Swift`
```swift
let employee = Person()
let section = Department()
employee.department = section
```

Properties can then be accessed directly, and Shark will automatically retrieve any related objects and allow you to access their properties.  For example `employee.deparment.location.address` will automatically retrieve the required objects to satisfy the statement by loading the related `Department` and `Location` objects.

### One-to-Many Relationships

You can define to-many relationships by adding methods to the inverse relationship.  For example, to relate in a to-many relationship `Department` and `Person` we would add the following method to `Department`.

`Objective-C`
```objective-c
- (SRKResultSet*)people {
    return [[[Person query] whereWithFormat:@"department = %@", self] fetch];
}
```
`Swift`
```swift
func people() -> SRKResultSet {
	return Person.query()
            	 .whereWithFormat("department = %@", withParameters: [self])
                 .fetch()
}
```

You can then safely use these results anywhere, and because an `SRKResultSet` is an array object, these can be iterated inline. `for (Person* employee in [department people]) {...}`.

## Indexing Properties

Shark supports indexing by overriding the `indexDefinitionForEntity` method and returning an `SRKIndexDefinition` object which describes all of the indexes that need to be maintained on the object.

`Objective-C`
```objective-c
+ (SRKIndexDefinition *)indexDefinitionForEntity {
    SRKIndexDefinition* idx = [SRKIndexDefinition new];
    [idx addIndexForProperty:@"name" propertyOrder:SRKIndexSortOrderAscending];
    [idx addIndexForProperty:@"age" propertyOrder:SRKIndexSortOrderAscending];
    return idx;
}
```
`Swift`
```swift
override class func indexDefinitionForEntity() -> SRKIndexDefinition {
	let idx = SRKIndexDefinition()
	idx.addIndexForProperty("name", propertyOrder: SRKIndexSortOrderAscending)
	idx.addIndexForProperty("age", propertyOrder: SRKIndexSortOrderAscending)
	return idx
}
```
These will automatically be matched to the appropriate query to aid performance.  All related object properties are automatically indexed as is required for caching.  So there would be no need, for instance, to add in an index for `Person.department` as it will have already been created.

### Default Values
You can specify a set of default values for whenever a new `SRKObject` is created, by overriding the method `defaultValuesForEntity`, and returning a dictionary of default values:
`Objective-C`
```objective-c
+ (NSDictionary *)defaultValuesForEntity {
    return @{@"age": @(36), @"name" : @"Billy"};
}
```
`Swift`
```swift
override class func defaultValuesForEntity() -> [NSObject : AnyObject] {
    return ["name" : "Billy", "age" : 36]
}
```
## Triggers
Shark objects all have the same methods available for them, to enforce constraints and check validity before or after writes have been made.

### entityWillInsert(), entityWillUpdate(), entityWillDelete() returning bool
Objects receive this method before any action has been carried out.  In here you can test to see if you wish the operation to continue.  If `true` is returned then the operation is told to continue, but if `false` is retuned then the transaction is aborted, and the commit returns false.
`Objective-C`
```objective-c
- (BOOL)entityWillDelete {
    return self.persons.count == 0;
}
```
`Swift`
```swift
override func entityWillDelete() -> Bool {
    return Department.people().count == 0;
}
```

### entityDidInsert(), entityDidUpdate(), entityDidDelete()
Objects receive this message after an event has happened and after the transaction is complete.

### Printing objects using print(), NSLog or po
We have provided a printable dictionary styled output which, when called, produces output like below.
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

## Writing Objects
Shark looks to simplify the persistence of objects down to a simple method `commit`.  This can be called at any moment and from any thread.  If an object contains either a single or multiple related objects within it, then calling `commit` on the parent object will automatically store all the subsequent objects too.

`Objective-C`
```objective-c
// Create a new object
Person* thisPerson = [Person new];

// Set some properties
thisPerson.age = 38;
thisPerson.payrollNumber = 123456;
thisPerson.name = @"Adrian Herridge";

// Persist the object into the datastore
[thisPerson commit];
```
`Swift`
```swift
// Create a new object
var thisPerson = Person()

// Set some properties
thisPerson.age = 38;
thisPerson.payrollNumber = 123456;
thisPerson.name = "Adrian Herridge";

// Persist the object into the datastore
thisPerson.commit()
```

Objects are committed immediately and are written to the store in an atomic fashion.  They will become immediately queryable upon completion.

### .commitOptions (property)

the commitOptions property is present in all SRKObjects, and allows the developer to control on an object-by-object basis how SharkORM behaves when asked to commit certain objects.

The following properties are used to control the logic and add fine grain control:

**postCommitBlock**
Called once a successful commit has completed

**postRemoveBlock**
Called after an object has been removed from the data store

**ignoreEntities**
Allows the developer to specify an array of child/related entities that will not be persisted when the parent object is commited. 

**commitChildObjects**
If set, then all child/related entitied will not automatically be commited too.

**resetOptionsAfterCommit**
If set, then all defaults will be restored and all blocks cleared.

**raiseErrors**
If set to false then any errors generated are ignored and not raised with the delegate.  Transactions will also not be failed.

**triggerEvents**
If set to true then events are raised for insert,update,delete operations.



### Writing in Transactions
For some batch storage situations, it may be better to batch a lot of writes into a single transaction, this will improve speed, and give you atomicity over the persistence to the data store.  All changes to all objects will be rolled back upon any raised error within the block.  Event triggers will be not be executed until successful completion of the transaction.

You may manually fail a transaction by calling SRKFailTransaction() within the block, allowing developers to abort and rollback based on applicaiton logic.

`Objective-C`
```objective-c
[SRKTransaction transaction:^{
    // Create a new object
    Person* thisPerson = [Person new];
    thisPerson.name = @"Adrian Herridge";
    [thisPerson commit];
} withRollback:^{}];
```
`Swift`
```swift
SRKTransaction.transaction({ 
    // Create a new object
    var thisPerson = Person()
    thisPerson.name = "Adrian Herridge";
    thisPerson.commit()
    }) { 
        // the rollback on failure 
    }
```

## Querying
To retrieve objects back, we use the SRKQuery object that is associated with every `SRKObject` class. This then takes optional parameters such as `where`, `limit`, `orderBy` & `offset`. All of the parameters return the same query object back, enabling the building of a query within a single nested instruction.

The final call to a query object is made using `fetch`, `count`, `sum`, `fetchLightweight` & `fetchAsync` which will then execute the query and return the results.

An example to fetch an entire table:
`Objective-C`
```objective-c
SRKResultSet* results = [[Person query] fetch];
```
`Swift`
```swift
var results : SRKResultSet = Person.query().fetch()
```
Queries can be built up using a FLUENT interface, so every call except a call to a retrieval method returns itself as a `SRKQuery`, allowing you to nest your parameters. 
`Objective-C`
```objective-c
SRKResultSet* results = [[[[[Person query]
                       		where:@"age = 35"]
                       		limit:99]
                     	  orderBy:@"name"]
                        fetch];
```
`Swift`
```swift
var results = Person.query()
					.whereWithFormat("age = %@", withParameters: [35])
					.limit(99).orderBy("name")
					.fetch()
```

As of v2.0.8 you can now use object dot notation to query related objects via the property path.  If we take the example of a Person class which is related to the Department class via the `department` property.
 
`Objective-C`
```objective-c
[[[Person query] where:@"department.name = 'Test Department'"] fetch]
```
`Swift`
```swift
Person.query().whereWithFormat("department.name = %@", withParameters: ["Test Department"]).fetch()
```
Where `name` is within a related object, SharkORM will now automatically re-arrange the query and join the two tables on that relationship and therefore validate that condition.

### Supported parameters to `SRKQuery`
Shark supports the following optional parameters to a query:

### where, whereWithFormat (and with parameters).  
This is the query string supplied to the query, and can contain format specifiers along with object to be placed into the query as normal parameter options.  Supported format specifiers are `%@`,`%i`,`%u`,`%d`,`%s`,`%f`,`%ul`,`%ull`.

`%@` objects can also be Arrays and Sets for use in subqueries, such as `@"department IN (%@)", @[@(1),@(2),@(3)]`.
### limit
Specifies the limit to the number of query results to return
### orderBy
Specifies the order by which the `SRKResultSet` will be returned.  These can be chained together to produce multiple vectors.  Example, `.....orderBy("Name").orderBy(descending: "age").fetch()`
### offset
Specifies the offset in the values to be retrieved, to allow developers to only retrieve a window of data when required.
### batch
This, although it does not affect the query, does allow developers to iterate through a large data set without having the performance and memory issue of dealing with the entire data set.  If a batch size of 10 is specified, then the `SRKResultSet` will perform an entire query, but will only fully retrieve the first 10 objects.  Then, it will maintain a window of the batch size when iterating through the results, automatically fetching them in batches.  This enables developers to optimise their system without the need to change the way their code is written.
### joinTo
Shark allows `LEFT JOIN` unions to be made, to allow for faster and less nested queries.  See Joins for more info.
## Other types of Query
In addition to retrieving entire objects there are also additional types of queries which help developers solve other problems.
### fetchLightweight
Fetches an object from the store, except it does not retrieve any property values.  These are lazily loaded upon access, and can be configured to then be permanently available of freed immediately.
### fetchAsync
Performs an asynchronous query on a background thread and then executes the supplied block when the results are complete.

### count
Returns a count of the query, the same as `COUNT(*)` would.
### sum
Returns a `SUM(field)` value from the supplied property name, these can also be compound, such as `SUM(property1 + property2)`.
### distinct
Returns an NSArray of the distinct values for a particular column, it is used like `distinct("surname")`.
### groupBy
Returns an NSDictionary, which is grouped by the specified property `groupBy("surname")`.
### ids
Returns the PK values of the matching objects, this is a faster way to store results for use in a subquery.  Although, in practice it is little faster than using lightweight objects.

## Joins
Joins represent the most powerful feature of SQL as the way any RDBMS is optimised is not through subqueries, but through joins and null checking.

In Shark, for the time being, all joins are `LEFT JOIN`.  Simply because we have to retrieve whole objects from the originating query class.  But joins can be multiple and compound.

Example of a join from `[Person] -> [Department]`
`Objective-C`
```objective-c
[[Person query] joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
```
`Swift`
```swift
Person.query()
	  .joinTo(Department, leftParameter: "department", targetParameter: "Id")
```

But you can also create an `[Person]->[Department]->[Location]` three way join, using the result of the first join to perform the second.
`Objective-C`
```objective-c
[[[Person query] joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                 joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Id"]
```
`Swift`
```swift
Person.query()
      .joinTo(Department, leftParameter: "department", targetParameter: "Id")
      .joinTo(Location, leftParameter: "Department.location", targetParameter: "Id")
```
Once you have performed your join, the results are stored per object in a dictionary `joinedResults`.

An example of output looks like this.
```
{
    "Department.Id" = 61;
    "Department.location" = 35;
    "Department.name" = Development;
    "Location.Id" = 35;
    "Location.locationName" = Alton;
}
```

### Removing objects
To remove an object from Shark you simply call `remove()` on this object, this will delete it form the data store and sterilise it to ensure it cannot be accidentally written back at a later date.  To optimise the bulk removal of objects, a query can be combined with a call to `removeAll()` on the result set to delete many objects at once.

`Objective-C`
```objective-c
[[[[Person query] where:@"age < 18"] fetch] removeAll];
```
`Swift`
```swift
Person.query()
      .whereWithFormat("age < %@", withParameters: [18])
      .fetch()
      .removeAll()
```

The longhand version of this is:
`Objective-C`
```objective-c
for (Person* person in [[Person query] fetch]) {
	[person remove];
}
```
`Swift`
```swift
for person in Person.query().fetch() {
	person.remove()
}
```

## Event handling
Shark events fall into two caregories, the first being events on an individual object and the second being events on a class.

Class events are raised when there has been any underlying change in the values stored in a class.  This is useful for updating a view when data is written on a background thread, or event triggers are actioned.

Registering an event block simply requires you to create a new `SRKEventHandler` object by calling a creation method on the class.
`Objective-C`
```objective-c
SRKEventHandler* eHandler = [Person eventHandler];
[eHandler registerBlockForEvents:SharkORMEventInsert withBlock:^(SRKEvent *event) {
        // update the tableview here
} onMainThread:YES];
```
`Swift`
```swift
let eHandler = Person.eventHandler()
eHandler.registerBlockForEvents(SharkORMEventInsert, withBlock: { (event: SRKEvent!) in
        // update the tableview here
}, onMainThread: true)
```

For object event handlers, all individual objects have the ability to register blocks against them by just making the same call to `registerBlockForEvents`.  This will then automatically make the object `live` and will observe any changes to that corresponding object within the datastore, these will happen across any thread.

## Requirements:

- CocoaPods 1.0.0


