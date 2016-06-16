Shark iOS ORM
============

Shark is a fully featured and FREE to use ORM for iOS.

Replace CoreData whilst keeping your existing managed objects, but dump the predicates and long-winded syntax.

Instead use a simple and clean object syntax, with fast and concise inline queries.

Shark even has a conversion method to migrate your existing CoreData tables across.

Regularly updated and in constant use within many public applications it thrives on feedback from other developers and is supported by the authors via StackOverflow or directly via email.

It's mantra is simple, to be fast, simple to implement and the first choice for any developer.

## Getting started

Integrating Shark into your project could not be simpler. This guide should be all you need to get you started and wondering how you ever developed iOS apps without it.

Every effort has been made to ensure that you can get working as quickly as possible, from supporting as many data types as possible and working with your existing classes to an absolute bare minimum of configuration required to integrate the framework.

### Requirements

| Shark Version | Minimum iOS Target  |                                   Notes                                   |
|:--------------------:|:---------------------------:|:----------------------------:|:-------------------------------------------------------------------------:|
|          2.x.x         |            iOS 8            | Xcode 7 is required. |

###Install From Cocoapods

####To install it, simply add the following line to your Podfile:
```ruby
pod "SharkORM"
```

## Usage

### Setting up your project

Once you have added the SharkORM framework into your application, you will need to start it as soon as possible in your application lifecycle.  SRKDelegate needs to be set as well, we recomend this is added to your application delegate.

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
	SharkORM.setPersistSynthesizedProperties(true)
	SharkORM.openDatabaseNamed("myDatabase")
	
	return true
}
```
###Creating Data Objects
SharkORM objects are normal classes with properties defined on them, the ORM then inspects all these classes and mirrors their structure in a SQLite database. If you add or remove columns then the tables are updated to represent the current structure of the classes.

In Objective-C properties need to be implemented using `@dynamic`, this is to indicate to the ORM that it will control the fetching and setting of these values from the database, and in Swift the property is defined as `var dynamic`

####Example Object
`Objective-C`
```objective-c
//  Header File : Person.h
#import <SharkORM/SharkORM.h>

@interface Person : SRKObject
@property NSString*         name;
@property int               age;
@property int               payrollNumber;
@end

// Source File : Person.m
#import "Person.h"

@implementation Person
@dynamic name,age,payrollNumber;
@end

```
`Swift`
```Swift
@objc(Person)
class Person: SRKObject {
	dynamic var name : String!
	dynamic var age : NSNumber!
	dynamic var payrollNumber : NSNumber!
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

- CocoaPods 0.31
