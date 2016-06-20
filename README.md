Shark ORM
============

Shark allows you to create a model layer in your iOS, macOS or tvOS app naturally, using simple and clean syntax.  Shark does as much of the heavy lifting for you, so you don't have to put unnecessary effort into dealing with your data objects.

Regularly updated with over 12k downloads over the past 4 years and in constant use within many public applications, thriving on feedback and input from other developers.

Its mantra is simple, to be fast, simple and the first choice for any developer.

## Getting started

Shark is designed to get your app working quickly, integrated as source code, or as a framework. 

### Requirements

| Shark Version | Minimum iOS Target  |                                   Notes                                   |
|:--------------------:|:---------------------------:|:----------------------------:|:-------------------------------------------------------------------------:|
|          2.x.x         |            iOS 6 as source, iOS 8 as framework            | Xcode 7 is required. |
|          2.x.x         |            tvOS 9 as source and framework            | Xcode 7 is required. |
|          2.x.x         |            macOS 10.8 as source and framework            | Xcode 7 is required. |
|          2.x.x         |            watchOS 2 as source and framework            | Xcode 7 is required. |


###Install From Cocoapods

####To install it, simply add the following line to your Podfile:
```ruby
pod "SharkORM"
```
###Install as Framework
Download the source code from GitHub and compile the SharkORM framework target, and then within your application,  add the following:

```objective-c
// include the framework header within your app, for Swift add this to the bridging header
#include <SharkORM/SharkORM.h>
```
###Install as Source
Download the source code from GitHub and add to your target the contents of Core and SQLite:

```objective-c
// include the header within your app, for Swift add this to the bridging header
#include “SharkORM.h”
```

##Getting help and support
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
###Objects
SharkORM objects are normal classes with properties defined on them, the ORM then inspects all these classes and mirrors their structure in a SQLite database automatically. If you add or remove columns, then the tables are updated to represent the current structure of the classes.

You can use these classes in much the same way as any other class  in the system,  and they can be extended with methods and sub classed, and passed around from thread to thread with no problem.

In Objective-C properties need to be implemented using `@dynamic`, this is to indicate to the ORM that it will control the fetching and setting of these values from the database, and in Swift the property is implemented as `var dynamic`

####Example Object
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

##Supported Types

Shark supports the following types: `BOOL`, `bool`, `int`, `int64`, `uint`, `uint64`, `float`, `double`, `long`, `long long`, `unsigned long long`, `NSString`, `NSDate`, `NSData`, `NSNumber`.

##Relationships

`SRKObject`s can be linked to each other either by directly embedding them to create a one-to-one relationship (`dynamic var department : Department?`) or for a one-to-many relationship we employ the use fo a method which returns either an `NSArray` or `SRKResultSet` object.

With the Person object already defined, and with a property department lets look at the Department class.

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

###One-to-One Relationships

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

###One-to-Many Relationships

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

##Indexing Properties

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

###Default Values

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

###Creating objects, setting values & persistance
`Objective-C`
```objective-c
// Create a new object
Person* thisPerson = [Person new];

// Set some properties
thisPerson.age = 37;
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
thisPerson.age = 37;
thisPerson.payrollNumber = 123456;
thisPerson.name = "Adrian Herridge";

// Persist the object into the datastore
thisPerson.commit()
```
###Querying objects
To retrieve objects back, we use the SRKQuery object that is associated with every `SRKObject` class. This then takes optional parameters such as where, limit, orderBy & offset. All of the parameters return the same query object back, enabling the building of a query within a single nested instruction.

The final call to a query object is made using fetch, count, sum, fetchLightweight & fetchAsync which will then execute the query and return the results.

Fetch an entire table

`Objective-C`
```objective-c
SRKResultSet* results = [[Person query] fetch];
```
`Swift`
```swift
var results : SRKResultSet = Person.query().fetch()
```
Query example with parameters

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
var results : SRKResultSet = Person.query().whereWithFormat("age = %@", withParameters: [35]).limit(99).orderBy("name").fetch()
```

###Removing objects
`Objective-C`
```objective-c
for (Person* person in [[Person query] fetch]) {
	[person remove];
}

// or the shorthand is to use the removeAll method on the SRKResultSet object
[[[Person query] fetch] removeAll];
```
`Swift`
```swift
for person in Person.query().fetch() {
	person.remove()
}

// or the shorthand is to use the removeAll method on the SRKResultSet object
Person.query().fetch().removeAll()
```
###Other types of query
There are other types of fetches in addition to just fetch, such as **count**, **sum**, **groupBy** and **ids**

`Objective-C`
```objective-c
/* count the rows within the Person table */
int count = [[Person query] count];
 
/* add all of the ages together */
double total = [[Person query] sumOf:@"age"];
 
/* group all the people together by the surname property */
NSDictionary* peopleBySurname = [[Person query] groupBy:@"name"];
 
/* get just the primary keys for a query, useful to save memory */
NSArray* ids = [[Person query] ids];
```
`Swift`
```swift
/* count the rows within the Person table */
var count = Person.query().count()

/* add all of the ages together */
var total = Person.query().sumOf("age")

/* group all the people together by the surname property */
var peopleBySurname = Person.query().groupBy("name")

/* get just the primary keys for a query, useful to save memory */
var ids = Person.query().ids();
```

## Requirements:

- CocoaPods 1.0.0

