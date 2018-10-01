//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

#ifndef __SHARKORM_H
#define __SHARKORM_H

#import <Foundation/Foundation.h>
#import <objc/message.h>

/* components of SharkORM, developers only need import this header file */

@class SRKEntity;
@class SRKRelationship;
@class SRKEvent;
@class SRKEventHandler;
@class SRKQuery;
@class SRKTransaction;
@class SRKRawResults;
@class SRKIndexProperty;
@class SRKObject;
@class SRKStringObject;

typedef void(^SRKTransactionBlockBlock)(void);

/**
 * Called from within a transaction block to manually fail a transaction and cause a rollback.  Example, `SRKFailTransaction();`
 *
 * @return void
 */
void SRKFailTransaction(void);

/**
 * SRKTransaction class, for wrapping multiple insert/update/delete commands within a single operation.
 */
@interface SRKTransaction : NSObject

/**
 * Creates a new transaction for the current executing thread, which then executes the transaction block that was passed into the object, if the transaction failes in anypart the database changes are rolled back and the rollback block is called.
 
 *
 * @param transaction:(SRKTransactionBlockBlock*)transaction A valid SRKTransactionBlockBlock, any objects which are commited to removed within this block, will be dealt with within a single transaction.
 * @param withRollback:(SRKTransactionBlockBlock*)rollback A valid SRKTransactionBlockBlock, if executed all database objects are restored back to their previos state before the transaction began.
 * @return void
 */
+ (void)transaction:(nullable SRKTransactionBlockBlock)transaction withRollback:(nullable SRKTransactionBlockBlock)rollback;

@end

typedef enum : int {
    SRK_RELATE_ONETOONE = 1,
    SRK_RELATE_ONETOMANY = 2,
} SRKRelationshipType;

/**
 * Settings class for SharkORM, returned from the delegate when the engine is initialized.
 
 */
@interface SRKSettings : NSObject

/// when TRUE all dates are stored within the system as numbers for performance reasons instead of ANSI date strings.
@property BOOL                      useEpochDates;
/// The SQLite standard journaling mode that will be used on all connections, the defalut is WAL.
@property (strong, nullable) NSString*        sqliteJournalingMode;
/// when TRUE, all objects created will automatically be registered within the default managed object domain, this will save the developer from having to manually add the parameter to any queries or individually to objects.
@property BOOL                      defaultManagedObjects;
/// the default managed object domain used for new objects when defaultManagedObjects is set to TRUE.  If not set, this defaults to "SharkORM.default"
@property (strong, nullable)                  NSString* defaultObjectDomain;
/// The folder path that the database file should be created in not including the filename, this must be a valid path capable of being turned into an NSURL.
@property (nonatomic,strong, nullable)        NSString* databaseLocation;
/// the filename of the default database file, e.g. "MyApplication".  SharkORM will automatically append ."db" onto the end of the filename.  Not including the path to the file.
@property (nonatomic,strong, nullable)        NSString* defaultDatabaseName;
/// this is the AES256 encryption key that is used when properties are specified as encryptable.
@property (strong, nullable)                  NSString* encryptionKey;
/// tells SharkORM if you wish to retain values for lightweight objects once they are done with.
@property BOOL                      retainLightweightObjects;

@end

/**
 * Contains performance anaylsis information about a query that was performed by the system.
 */

@interface SRKQueryProfile : NSObject

/// The number of rows returned by the query.
@property  int rows;
/// The time it took to parse the query before executing it.
@property  int parseTime;
/// The seek time to the first record, usually an indication of a value in the query not being indexed.  But also includes other overheads when SharkORM has to check the cache or load an index.
@property  int firstResultTime;
/// The overall time it took to perform the query, excluding the subsequent time it took to analyse the performance and gain extra information from an EXPLAIN statement.
@property  int queryTime;
/// The time (in ms) it took to gain an appropriate lock on the database to perform the query, this is often symptomatic of many competing threads looking to gain exclusive access to a table at the same time.
@property  int lockObtainTime;
/// The query plan as returned by SQLite
@property  (nonatomic, strong, nullable) NSArray* queryPlan;
/// The query that was generated from the SRKQuery object.
@property  (nonatomic, strong, nullable) NSString* sqlQuery;
/// The compiled query with the parameters included.
@property  (nonatomic, strong, nullable) NSString* compiledQuery;
/// The resultant output from the query.
@property  (nonatomic, strong, nullable) NSObject* resultsSet;

@end

/**
 * Ad error raised by SharkORM, gives you the message from the core, as well as the SQL query that was generated and caused the fault.
 
 */
@interface SRKError : NSObject

/// The error message that was returned from the core of SharkORM.
@property  (nonatomic, retain, nullable)  NSString* errorMessage;
/// The query that caused the error.
@property  (nonatomic, retain, nullable)  NSString* sqlQuery;

@end

@protocol SRKDelegate <NSObject>

@optional

/// Return a SharkORMSettings* object to override the default settings, this will be asked for on initialization of the first persistable object.
- (nonnull SRKSettings*)getCustomSettings;
/// This method is called when the database has been successfully opened.
- (void)databaseOpened;
/// This method is called when an error occours within SharkORM.
- (void)databaseError:(nonnull SRKError*)error;
/// This method, if implemented, will profile all queries that are performed within SharkORM.  Use the queryTime property within the SRKQueryProfile* object to filter out only queries that do not meet your performance requirements.
- (void)queryPerformedWithProfile:(nonnull SRKQueryProfile*)profile;
/// An object that did not support a valid encoding mechanisum was attempted to be written to the database.  It is therefore passed to the delegate method for encoding.  You must return an NSData object that can be stored and later re-hydrated by a call to "decodeUnsupportedColumnValueForColumn"
- (nullable NSData*)encodeUnsupportedColumnValueForColumn:(nonnull NSString*)column inEntity:(nonnull NSString*)entity value:(nonnull id)value;
/// Previously an object was persistsed that was not supported by SharkORM, and "encodeUnsupportedColumnValueForColumn" was called to encode it into a NSData* object, this metthod will pass back a hydrated object created from the NSData*
- (nullable id)decodeUnsupportedColumnValueForColumn:(nonnull NSString*)column inEntity:(nonnull NSString*)entity data:(nonnull NSData*)value;

@end

typedef void(^SRKConfigurationBlock)(void);
@interface SRKConfiguration : NSObject {
}
@property (copy, nullable) SRKConfigurationBlock startupBlock;
@end

/**
 * SharkORM class, always accessed through class methods, there is only ever a single instance of the database engine.
 */

NS_ASSUME_NONNULL_BEGIN
typedef void(^SRKGlobalEventCallback)(SRKEntity* entity);
NS_ASSUME_NONNULL_END

@interface SharkORM : NSObject {
    
}

/**
 * Sets the SRKDelegate object that will be used by SharkORM to gain access to settings and to provide the deleoper with access to feedback.
 *
 * @param aDelegate Must be an initialised object that implements the SRKDelegate protocol.
 * @return void
 */
+(void)setDelegate:(nullable id<SRKDelegate>)delegate;
/**
 * Sets the SRKConfigurationBlock object for the ORM, allowing the ORM to startup across multiple threads and block entity access until the initial setup has been completed.
 *
 * @param configBlock, this usually contains the "setDelegate" and "openDatabase" instructions.
 * @return SRKConfiguration*, used to allow the startup of Swift/Storyboard apps that have a lifecycle that starts in advance of the AppDelegate methods
 */
+(nonnull SRKConfiguration*)setStartupConfiguration:(nonnull SRKConfigurationBlock)configBlock;
/**
 * Contains the r/w settings for the ORM.  Developers can set the properties directly as opposed to having to respond to the delegate method
 *
 * @return SRKSettings*, settings object.
 */
+(nonnull SRKSettings*)settings;
/**
 * Used to pre-create and update any persistable classes, SharkORM by default, will only create or update the schema with objects when they are first referenced.  If there is a requirement to ensure that a collection of classes are created before they are used anywhere then you can use this method.  This is not required in most scenarios.
 *
 * @param (Class)class Array of Class* objects to be initialized
 * @return void
 */
+(void)setupTablesFromClasses:(nullable Class)classDecl,...;
/**
 * Migrates data from an existing CoreData database file into SharkORM, only the supplied object names are converted.  NOTE: If successful, the original file will be removed by the routine.  Existing Objects within the supplied list will be cleared from the database.
 *
 * @param filePath The full path to the CoreData file that needs to be converted.
 * @param tablesToConvert Array of SRKEntity class names to convert from the original CoreData file provided.
 * @return void
 */
+(void)migrateFromLegacyCoredataFile:(nonnull NSString*)filePath tables:(nonnull NSArray<NSString*>*)tablesToConvert;
/**
 * Opens or creates a database file from the given name.
 *
 * @param dbName The name of the database to open or create, this is not the full path to the object. By default the path defaults to the applcations Documents directory. If you wish to modify the path the file will exist in, then you will need to implement the "getCustomSettings" delegate method and return an alternative path.
 * @return void;
 */
+(void)openDatabaseNamed:(nonnull NSString*)dbName;
/**
 * Closes a database file of the given name, flushing all caches, and invalidating any objects that are still in use within the system.
 *
 * @return void;
 */
+(void)closeDatabaseNamed:(nonnull NSString*)dbName;
/**
 * Performs a free text query and returns the result as a INSERT INTO object.
 *
 * @param (NSString*) The query to be performed.
 * @return (SRKRawResults*);
 */
+(SRKRawResults* _Nonnull)rawQuery:(nonnull NSString*)sql;
/**
 * Allows the developer to specify a block to be executed against all INSERT events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any INSERT.
 * @return void;
 */
+(void)setInsertCallbackBlock:(nullable SRKGlobalEventCallback)callback;
/**
 * Allows the developer to specify a block to be executed against all UPDATE events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any UPDATE.
 * @return void;
 */
+(void)setUpdateCallbackBlock:(nullable SRKGlobalEventCallback)callback;
/**
 * Allows the developer to specify a block to be executed against all DELETE events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any DELETE.
 * @return void;
 */
+(void)setDeleteCallbackBlock:(nullable SRKGlobalEventCallback)callback;

@end

/*
 *      SRKRelationship
 */

@interface SRKRelationship : NSObject {
    
}
@property Class                                       sourceClass;
@property Class                                       targetClass;
@property (nonatomic, strong, nullable) NSString*     sourceProperty;
@property (nonatomic, strong, nullable) NSString*     targetProperty;
@property (nonatomic, strong, nullable) NSString*     linkTable;
@property (nonatomic, strong, nullable) NSString*     linkSourceField;
@property (nonatomic, strong, nullable) NSString*     linkTargetField;
@property (nonatomic, strong, nullable) NSString*     entityPropertyName;
@property (nonatomic, strong, nullable) NSString*     order;
@property (nonatomic, strong, nullable) NSString*     restrictions;
@property int                                         relationshipType;

@end

/*
 *      SRKIndexDefinition
 */

enum SRKIndexSortOrder : NSUInteger {
    SRKIndexSortOrderAscending = 1,
    SRKIndexSortOrderDescending = 2,
    SRKIndexSortOrderNoCase = 3
};

/**
 * Used to define a set of indexes within a persitable object.
 */
@interface SRKIndexDefinition : NSObject {
    
}
/** Convenience method to specify an array of property names to automatically create and maintain indexes on.  All indexes default to Ascending.
 */
- (nonnull instancetype)init:(nonnull NSArray<NSString*>*)properties;
/**
 * *DEPRICATED* Adds the definition for an index on a given object.
 *
 * @param propertyName The name of the property that you wish to index.
 * @param propertyOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @return SRKIndexDefinition
 */
- (nonnull SRKIndexDefinition*)addIndexForProperty:(nonnull NSString*)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder DEPRECATED_MSG_ATTRIBUTE("Use 'add:order:' instead");
/**
 * Creates an index for the named property
 *
 * @param property, The name of the property that you wish to index.
 * @param order, the order of the index, specified as a value of enum SRKIndexSortOrder.
 * @return SRKIndexDefinition
 */
- (nonnull SRKIndexDefinition*)add:(nonnull NSString*)property order:(enum SRKIndexSortOrder)order;
/**
 * Adds the definition for a compound index with an indefinite number of properties
 *
 * @param indexProperty A list of properties that makes up the compound index
 * @return void
 */
- (nonnull SRKIndexDefinition*)addIndexWithProperties: (nullable SRKIndexProperty *)indexProperty, ...;

/**
 * Adds a composite index on a given object with a sub index on an additional property.
 *
 * @param propertyName The name of the property that you wish to index.
 * @param propertyOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @param secondaryProperty The name of the second property that you wish to index.
 * @param secondaryOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @return void
 */
- (nonnull SRKIndexDefinition*)addIndexForProperty:(nonnull NSString*)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder secondaryProperty:(nonnull NSString*)secProperty secondaryOrder:(enum SRKIndexSortOrder)secOrder;

@end

@protocol SRKPartialClassDelegate

@required
/**
 * If implemented, SharkORM knows that this class is only a partial implementation of an existing SRKEntity derrived class.  These objects can be retrieved, but will remain sterile and cannot be commited back into the original table.
 *
 * @return (Class) The original SRKEntity derrived class definition on which this object is partially based.
 */
+ (nonnull Class)classIsPartialImplementationOfClass;

@end

enum SharkORMEvent {
    SharkORMEventInsert = 1,
    SharkORMEventUpdate = 2,
    SharkORMEventDelete = 4,
};

typedef void(^SRKEventRegistrationBlock)(SRKEvent* _Nonnull event);

/**
 * If implemented, SRKEventDelegate is used to notify an object that an event has been raised within a SRKEntity.
 */
@protocol SRKEventDelegate <NSObject>

@required
/**
 * Called when a SRKEntity class raises an INSERT, UPDATE or DELETE trigger.  This will only get called after the successful completion of the transaction within the database engine.
 *
 * @param (SRKEvent*)e The event object that was created from the SharkORM event model.
 * @return void
 */
- (void)SRKObjectDidRaiseEvent:(nonnull SRKEvent*)e;

@end

/*
 *      SRKResultSet
 */
/**
 * Contains the results from a fetch call to a SRKQuery object.  Subclassed from an NSArray, it contains two extra methods, removeAll & commitAll.  These are optimized to complete within a single transaction.
 */
@interface SRKResultSet : NSArray


- (BOOL)removeAll DEPRECATED_MSG_ATTRIBUTE("use method 'remove' instead");
/**
 * Removes all objects contained within the array from the database.  This is done within a single transaction to optimize performance.
 *
 * @return BOOL, true if operation was successful.
 */
- (BOOL)remove;

@end

/*
 *      SRKContext
 */

typedef     void(^contextExecutionBlock)(void);

/**
 * SRKContext objects are used to effect bulk operations across single or multiple tables.  You can not call commit on an object that has been added to a context.  Instead you call commit on the context itself, all activities will then be performed within an single transaction. NOTE: all SRKObjects have their own context already, and any activity performed on then is guaranteed to complete in an ATOMIC way.  This style of object management is provided in a legacy manner as this is a method that programmers are largely used to, but it is not a requirement.  SharkORM already groups together operations and performs them in bulk when it can to improve performance, the deleoper does not need to think about this when writing their application.
 */
@interface SRKContext : NSObject
/**
 * Adds an SRKEntity to a context.
 
 *
 * @param (SRKEntity*)entity The entity to add to the context.
 * @return void
 */
- (void)addEntityToContext:(nonnull SRKEntity*)entity;
/**
 * Removes an SRKEntity from a context.
 
 *
 * @param (SRKEntity*)entity The entity to be removed from the context.
 * @return void
 */
- (void)removeEntityFromContext:(nonnull SRKEntity*)entity;
/**
 * Used to test if an object is already a member of this context.
 
 *
 * @param (SRKObject*)entity The entity to be tested for its presence.
 * @return BOOL returns YES if this object exists in this context.
 */
- (BOOL)isEntityInContext:(nonnull SRKEntity*)entity;
/**
 * Commits all of the pending changes contained in SRKObject's within the context.
 
 *
 * @return BOOL returns YES if the operation was successful.
 */
- (BOOL)commit;

@end

/*
 *      SRKCommitOptions
 *
 */

/// a generic block to be executed after a commit/remove event.
typedef void(^SRKCommitOptionsBlock)(void);


/**
 * Defines a set of options which will be taken into account on an object by object basis when commiting or removing entities from the data store.  All SRKObjects' have a commit options property, and it is automatically populated with the ORM defaults.
 */
@interface SRKCommitOptions : NSObject

/// when TRUE all embedded/related entitied will be commited along with the originating entity.  Default is TRUE.
@property BOOL                              commitChildObjects;
/// when TRUE event notifications will be raised for any registered handlers attached to the entity.  Default is TRUE.
@property BOOL                              triggerEvents;
/// when populated with an array of child/related entities, these will not be commited or updated when the originating entity is written to or deleted from the data store.  Default is nil.
@property (nullable) NSArray*               ignoreEntities;
/// when TRUE errors will be raised within transactions and posted to the app delegate, when false syntax errors will not raise errors and will not fail a transaction block.  Default is TRUE.
@property BOOL                              raiseErrors;
/// when TRUE, the properties of this class object will be reset back to their defaults.  Any blocks that were assigned for post events will also be cleared and their memory released.
@property BOOL                              resetOptionsAfterCommit;
/// executed on the calling thread, after an object has been successfully persisted.
@property (copy, nullable) SRKCommitOptionsBlock      postCommitBlock;
/// executed on the calling thread, after an object has been successfully removed.
@property (copy, nullable) SRKCommitOptionsBlock      postRemoveBlock;

@end

/*
 *      SRKObject
 *
 */

/**
 * Specifies a persistable class within SharkORM, any properties that are created within a class that is derrived from SRKObject will need to be implemnted using dynamic properties and not synthesized ones.  SharkORM places its own get/set methods to ensure that all values are correct for the storage and column type.
 
 */

@interface SRKEntity : NSObject <NSCopying>

/// define a method for the description property
+ (nonnull NSString*)description;

/// Creates a SRKQuery object for this class
+ (nonnull SRKQuery*)query;

/// Returns the first object where the property is matched with value
+ (nullable id)firstMatchOf:(nonnull NSString*)property withValue:(nonnull id)value;

/// The event object for the entire class.
+ (nonnull SRKEventHandler*)eventHandler;

/// The primary key column, this is common and mandatory across all persistable classes.
/*
 *  The primary key is overridden in the SRKObject (Number PK),SRKStringObject (uuid/string pk) and SRKSyncObject just puls from SRKStringObject
 */
// @property (nonatomic, strong)   NSNumber* Id; /* Removed */

/// Joined data, if set this contains the results of the query from adjoining tables
@property (nonatomic, strong, readonly, nullable)   NSDictionary<NSString*,id>* joinedResults;

/// commit options class of type SRKCommitOptions.  Allows the developer to specify object specific options when commiting and removing entities from the data store.
@property (nonatomic, strong, nullable)   SRKCommitOptions* commitOptions;

/**
 * Initialises a new instance of the object, if an object already exists with the specified primary key then you will get that object back, if not you will net a new object with the primary key specified already.
 *
 * @param (NSObject*)priKeyValue The primary key value to look up an existing object
 * @return SRKObject* Either an existing or new class.
 */
- (nonnull instancetype)initWithPrimaryKeyValue:(nonnull id)priKeyValue; //DEPRECATED_MSG_ATTRIBUTE("use 'objectWithPrimaryKeyValue:' instead");
/**
 * Returns an object that matches the primary key value specified, if there is no match, nil is returned.
 
 *
 * @param (NSObject*)priKeyValue The primary key value to look up an existing object
 * @return SRKObject* Either an existing object or nil.
 */
+ (nullable instancetype)objectWithPrimaryKeyValue:(nonnull id)priKeyValue;
/**
 * Initialises a new instance of the object, the supplied dictionary will pre-populate the field values.
 *
 * @param (NSDictionary*)initialValues, in the format [<property as string>:<value as Any>]
 * @return SRKObject*.  A new object with the pre-populated values.
 */
- (nonnull instancetype)initWithDictionary:(nonnull NSDictionary<NSString*,id>*)initialValues;
/**
 * Creates a new dictionary [Field:Value] of the current values stored within the object.
 *
 * @return (NSDictionary<NSString*, NSObject*>*).  All the field values for the current object.
 */
- (nonnull NSDictionary<NSString*, NSObject*>*)asDictionary;
/**
 * Clones the values of an object into a new container
 *
 * @return SRKObject*.  A new object with the pre-populated values.
 */
- (nonnull instancetype)clone;
/**
 * Removes the object form the database
 *
 * @return BOOL returns NO if the operation failed to complete.
 */
- (BOOL)remove;
/**
 * Inserts or updates the object within the database.
 
 *
 * @return BOOL returns NO if the operation failed to complete.
 */
- (BOOL)commit;

/* these methods should be overloaded in the business object class */
/**
 * Before SharkORM attempts an operation it will ask the persitable class if it would like to continue with this operation.
 
 *
 * @return BOOL if YES is returned then SharkORM WILL complete the operation and it is guaranteed to complete.  All pre-requisite checks have been made and the statement compiled before getting to this point.  It is safe to use this method to cascade operations to other classes.
 */
- (BOOL)entityWillInsert;
/**
 * Before SharkORM attempts an operation it will ask the persitable class if it would like to continue with this operation.
 
 *
 * @return BOOL if YES is returned then SharkORM WILL complete the operation and it is guaranteed to complete.  All pre-requisite checks have been made and the statement compiled before getting to this point.  It is safe to use this method to cascade operations to other classes.
 */
- (BOOL)entityWillUpdate;
/**
 * Before SharkORM attempts an operation it will ask the persitable class if it would like to continue with this operation.
 
 *
 * @return BOOL if YES is returned then SharkORM WILL complete the operation and it is guaranteed to complete.  All pre-requisite checks have been made and the statement compiled before getting to this point.  It is safe to use this method to cascade operations to other classes. In the case of delete, you might wish to delete related records, or indeed remove this object from related tables.
 */
- (BOOL)entityWillDelete;
/**
 * Called after SharkORM has completed an action.
 
 *
 * @return void
 */
- (void)entityDidInsert;
/**
 * Called after SharkORM has completed an action.
 
 *
 * @return void
 */
- (void)entityDidUpdate;
/**
 * Called after SharkORM has completed an action.
 
 *
 * @return void
 */
- (void)entityDidDelete;
/**
 * Used to indicate to SharkORM that this class does not raise Insert, Update & Delete event notifications.
 *
 * @return (BOOL) If true is returned, event notifications will not be raised.  This will significantly improve the speed of I,U & D operations.
 */
+ (BOOL)entityDoesNotRaiseEvents;
/**
 * Used to specify the relationships between objects.  The class will be asked to return the relationship object for a certain property.
 ∫
 *
 * @param (NSString*)property The name of the property on the class that SharkORM is asking for clarification of its relationship with other objects.
 * @return (SRKRelationship*) The relationship object should fully exlain the connection between the property and other objects.  If you return nil then SharkORM will assume that this property is not related to other objects and it will be persisted as a normal field.
 */
+ (nullable SRKRelationship*)relationshipForProperty:(nonnull NSString*)property;
/**
 * Used to specify the indexes that need to be created and maintained on the given object.
 
 *
 * @return (SRKIndexDefinition*) return an index object to let SharkORM know which properties need to be indexed for performance reasons.  Primary keys are already indexed, as are any properties that are in fact other persisbale classes.  SharkORM will attempt to automatically calculate indexes from the relationships between your classes, but sometimes you may with to add them manually given feedback form the profiling mechanisum.
 */
+ (nullable SRKIndexDefinition*)indexDefinitionForEntity;
/**
 * Used to indicate to SharkORM that you wish to ignore ceratin properties and to not persiste them.
 *
 * @return (NSArray*) Return an array of property names, these will be used to create an ignore list.
 */
+ (nullable NSArray<NSString*>*)ignoredProperties;
/**
 * Used to specify the default values for a new entity, where the "key" is the property name and the "value" is a standard NSObject such as NSNumber / NSString / NSNull / NSData / NSArray.  Every new object will automatically have these properties set with their default values.  When adding a new property to a SRKObject class, SharkORM will create a new column.  This column will be populated with the default value as provided by this method.
 *
 * @return (NSDictionary*) return a dictionary object to specify default values for properties.
 */
+ (nullable NSDictionary<NSString*,id>*)defaultValuesForEntity;
/**
 * Specifies the properties on the class that should remain encrypted within the database. NOTE: you will not be able to perform optimised queries on these encrypted properties so they should only be used to encrypt sensitive data that would not normally be searched on.
 
 *
 * @return and (NSArray*) of property names that SharkORM should keep encrypted in the database.
 */
+ (nullable NSArray<NSString*>*)encryptedPropertiesForClass;
/**
 * Specifies the properties on the class that should be unique within the datastore, before a commit operation is performed a test is made to ensure another record with those exact properties does not already exist.  Commit will return NO/FALSE if there is an existant match.
 *
 * @return and (NSArray*) of property names that SharkORM should test for uniqueness.
 */
+ (nullable NSArray<NSString*>*)uniquePropertiesForClass;
/**
 * Specifies the database file that this particular class will be persisted in.  This enables you to have your persistable classes spanning many different files.
 
 *
 * @return (NSString*) alternative filename for storage of this class.  This will be created within the same folder as the main database.
 */
+ (nullable NSString*)storageDatabaseForClass;

/* partial classes */
+ (nullable Class)classIsPartialImplementationOfClass;

/* live objects */
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.
 
 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours, this will be called on the main thread.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(nonnull SRKEventRegistrationBlock)block;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.
 
 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(nonnull SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.
 
 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @param updateSelfWithEvent:(BOOL)updateSelf is used to specify if you wish the object to have its values updated with the changes that raised the event.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(nonnull SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread updateSelfWithEvent:(BOOL)updateSelf;
/**
 * Allows an object to become a member of a managed object domain, only objects within the same domain recieve value change notifications.
 
 * @param setManagedObjectDomain:(NSString*)domain  sets the domain that this object is managed within, idetical objects within the same domain will share property values which are updated when the objects are comitted to the store.
 * @return void
 */
- (void)setManagedObjectDomain:(nonnull NSString*)domain;
/**
 * Clears all event blocks within the object and stops the object from receiving event notifications.
 
 *
 * @return void
 */
- (void)clearAllRegisteredBlocks;

@end

@interface SRKObject : SRKEntity <NSCopying>

/// The primary key column, this is common and mandatory across all persistable classes.
@property (nonatomic, strong, nullable)   NSNumber* Id;

@end

/**
 * Every SRKObject class or instance contains an SRKEventHandler, which the developer can use to monitor activity within the object or class of objects.
 
 *
 */
@interface SRKEventHandler : NSObject

- (nonnull SRKEventHandler*)entityclass:(nonnull Class)entityClass;

@property (nonatomic, weak, nullable) id<SRKEventDelegate> delegate;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.
 
 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(nonnull SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread;
/**
 * Clears all event blocks within the object and stops the object from receiving event notifications.
 
 *
 * @return void
 */
- (void)clearAllRegisteredBlocks;

@end

/*
 *      SRKObject
 *
 */

/**
 * Specifies a persistable class within SharkORM, any properties that are created within a class that is derrived from SRKObject will need to be implemnted using dynamic properties and not synthesized ones.  SharkORM places its own get/set methods to ensure that all values are correct for the storage and column type.
 
 */
@interface SRKStringObject : SRKEntity <NSCopying>

//NOTE:  There is no way around this, for convenience for the developer to 'know' the type.  The base class inspects the value to check its class, but this is bad OO practice that leads to convenient and nice API for the developer so suck it up, it is NOT dangerous as the public facing API is strongly typed and safe, and well anticipated by the backstore.

/// The primary key column, this is common and mandatory across all persistable classes.  In this case it is forced to NSString* to allow string primary keys in Swift.

@property (nonatomic, strong, nullable)   NSString* Id;

@end

/**
 * SRKEvent* is an container class, which is passed to event objects as a parameter.
 
 *
 */
@interface SRKEvent : NSObject

/// The type of event that triggered the creation of this object
@property  enum SharkORMEvent               event;
/// The persistable object that created this event
@property  (nonatomic, weak, nullable) SRKEntity*      entity;
/// The properties that have changed within this object since its last comital into the database.
@property  (nonatomic, strong, nullable) NSArray*     changedProperties;

@end

/**
 *  SRKQueryAsyncHandler* is the event handler for async queries, allows them to be canceled and for progress to be reported.
 *
 *
 */
@interface SRKQueryAsyncHandler : NSObject

/**
 * Cancels an in progress query.  If called on an expired query that has already completed then it will have no effect.
 
 *
 * @return void
 */
- (void)cancelQuery;

@end

typedef void(^SRKQueryAsyncResponse)(SRKResultSet* _Nonnull results);

/**
 * A SRKQuery class is used to construct a query object and return results from the database.
 
 *
 *
 */

@interface SRKQuery : NSObject

/* parameter methods */
/**
 * Specifies the WHERE clause of the query statement
 
 *
 * @param (NSString*)where contains the parameters for the query, e.g. " forename = 'Adrian' AND isEmployee = 1 "
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)where:(nonnull NSString*)where;
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.
 
 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename = %@ ", @"Adrian"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)whereWithFormat:(nonnull NSString*)format,... ;// DEPRECATED_MSG_ATTRIBUTE("use 'where:parameters:' instead, and you must now use '?' instead of '%@' for place markers");
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.
 
 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename = %@ "
 * @param (NSArray*)params is an array of parameters to be placed into the format string, useful for constructing queries through a logic path.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)whereWithFormat:(nonnull NSString*)format withParameters:(nonnull NSArray*)params; // DEPRECATED_MSG_ATTRIBUTE("use 'where:parameters:' instead, and you must now use '?' instead of '%@' for place markers");
/**
 * Specifies the WHERE clause of the query statement, and the parameters to be bound to the statement.
 *
 * @param where contains the parameters for the query, e.g. where:@" forename = ? "
 * @param parameters is an array of parameters to be placed into the format string, useful for constructing queries through a logic path.
 * @return SRKQuery* this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)where:(NSString* _Nonnull)statement parameters:(NSArray* _Nonnull)parameters;
/**
 * Limits the number of results retuned from the query
 
 *
 * @param (int)limit the number of results to limit to
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)limit:(int)limit;

- (nonnull SRKQuery*)orderBy:(nonnull NSString*)order DEPRECATED_MSG_ATTRIBUTE("use 'order:' instead.");
/**
 * Specifies the property by which the results will be ordered.  This can contain multiple, comma separated, values.
 *
 * @param (NSString*)order a comma separated string for use to order the results, e.g. "surname, forename"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)order:(nonnull NSString*)order;
/**
 * Specifies the property by which the results will be ordered in decending value.  This can contain multiple, comma separated, values.
 
 *
 * @param (NSString*)order a comma separated string for use to order the results, e.g. "surname, forename"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)orderByDescending:(nonnull NSString*)order;
/**
 * Specifies the number of results to skip over before starting the aggregation of the results.
 
 *
 * @param (int)offset the offset value for the query.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)offset:(int)offset;
/**
 * Specifies the number of results to retrieve in a batch, the SRKResultSet is then created using a batch store co-ordinator.
 *
 * @param (int)batchSize the batch size of the query.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)batchSize:(int)batchSize;
/**
 * Specifies the managed object domain that the query results will be added to.
 
 *
 * @param (NSString*)domain the domain value as a string, e.g. "network-objects"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)domain:(nonnull NSString*)domain;
/**
 * Used to include "joined" data within the query string, you must use the tablename.columnname syntax within a where statement
 
 *
 * @param (Class)joinTo the class you would like to pwrform a SQL JOIN with
 * @param (NSString*)leftParameter the property name that you would like to use within the local object to match against the target
 * @param (NSString*)targetParameter the property within the class you wish to join with that will be matched with the left parameter.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (nonnull SRKQuery*)joinTo:(nonnull Class)joinClass leftParameter:(nonnull NSString*)leftParameter targetParameter:(nonnull NSString*)targetParameter;

/* execution methods */
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.
 
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKResultSet*)fetch;
/**
 * Performs the query and returns the first match found form the query.
 *
 * @return (SRKObject*) results of the query.
 */
- (nullable SRKObject*)first;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.
 
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKResultSet*)fetchLightweight;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.
 
 * @param prefetchProperties:(NSArray*) the properties you would like to retieve with the fetch.
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKResultSet*)fetchLightweightPrefetchingProperties:(nonnull NSArray*)properties;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.
 
 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (nonnull SRKQueryAsyncHandler*)fetchAsync:(nonnull SRKQueryAsyncResponse)_responseBlock;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.
 
 * @param onMainThread: specify weather you want to execute the results block on the main thread.
 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (nonnull SRKQueryAsyncHandler *)fetchAsync:(nonnull SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
/**
 * Performs the query and returns only the primary keys (Id parameter).  This is often much quicker if the fully hydrated objects are not required.
 
 *
 * @return (NSArray*) primary keys of the query.
 */
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.
 
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKQueryAsyncHandler*)fetchLightweightAsync:(nonnull SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.
 
 * @param prefetchProperties:(NSArray*) the properties you would like to retieve with the fetch.
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKQueryAsyncHandler*)fetchLightweightPrefetchingPropertiesAsync:(nonnull NSArray*)properties withAsyncBlock:(nonnull SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.
 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (nonnull NSArray*)ids;
/**
 * Performs the query and returns the results all within the same SRKContext, you will always get an object back even if there are no results.
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKResultSet*)fetchWithContext;
/**
 * Performs the query and returns the results all within the SRKContext specified in the context parameter, you will always get an object back even if there are no results.
 * @param (SRKContext*)context specifies the context that all the results should be added to.
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (nonnull SRKResultSet*)fetchIntoContext:(nonnull SRKContext*)context;
/**
 * Performs the query and returns the results grouped by the specified property, you will always get an object back even if there are no results.
 
 * @param (NSString*)propertyName the property name to group by
 * @return (NSDictionary*) results of the query, the key values are the distinct values of the paramater that was specified.
 */
- (nonnull NSDictionary*)groupBy:(nonnull NSString*)propertyName;
/**
 * Performs the query and returns the count of the rows within the results.
 *
 * @return (int)count .
 */
- (uint64_t)count;
/**
 * Performs the query and returns an array of distinct values of the specified property name.
 *
 * @param (NSString*)propertyName the property name to select the distict values of
 * @return (NSArray*) results of the query, the key values are the distinct values of the paramater that was specified.
 */
- (nonnull NSArray<id>*)distinct:(nonnull NSString*)propertyName;

/**
 * Performs the query and returns the sum of the numeric property that is specified in the parameter.
 * @param (NSString*)propertyName the property name to perform the SUM aggregation function on.
 * @return (double)  sum of the specified parameter across all results.
 */
- (double)sumOf:(nonnull NSString*)propertyName;

@end

/**
 * A SRKRawResults class is used to store results from raw queries.
 *
 *
 */
@interface SRKRawResults : NSObject

@property (nonatomic, nonnull) NSMutableArray* rawResults;
@property (nonatomic, nullable) SRKError* error;

/**
 * Contains the number if rows in the result set from a raw query
 *
 * @return (NSInteger) the count of rows.
 */
- (NSInteger)rowCount;
/**
 * Contains the number if columns in the result set from a raw query
 *
 * @return (NSInteger) the number of columns.
 */
- (NSInteger)columnCount;
/**
 * Retrieves a value from the dataset, given the column name and the rown index.
 *
 * @param (NSString*)columnName.  The named column from the original queries.
 * @param (NSInteger)index. The row index for the result to retrieve.
 * @return (id), this is the value contained in the column.  This can be, NSString, NSDate, NSNumber, NSNull.
 */
- (nullable id)valueForColumn:(nonnull NSString*)columnName atRow:(NSInteger)index;
/**
 * Retrieves a column from the dataset, given the index.
 *
 * @param (NSInteger)index. The index for the column name to retrieve.
 * @return (NSString*), the column name to be used in queries.
 */
- (nullable NSString*)columnNameForIndex:(NSInteger)index;

@end

/**
 * A SRKIndexProperty is used to store the name and sort order of a single column within a compound index
 *
 *
 */
@interface SRKIndexProperty : NSObject

@property (strong, nullable) NSString*   name;
@property enum SRKIndexSortOrder order;

/**
 * Formats the object's SRKIndexSortOrder into the string representation necessary for creating indices
 *
 * @return (NSString) the string representation of the sort order
 */
-(nonnull NSString*) getSortOrderString;

/**
 * Formats the object's SRKIndexSortOrder into the string representation necessary for naming indices
 *
 * @return (NSString) the string representation of the sort order
 */
-(nonnull NSString*) getSortOrderIndexName;

/**
 * Initializes a new SRKIndexProperty object
 *
 * @param (NSString*)columnName The named column used within the index
 * @param (enum SRKIndexSortOrder)sortOrder The direction in which the index should sort
 * @return (id)
 */
-(nonnull instancetype) initWithName:(nonnull NSString*)columnName andOrder:(enum SRKIndexSortOrder) sortOrder;

/**
 * Initializes a new SRKIndexProperty object with a default sort order of Ascending
 *
 * @param (NSString*)columnName The named column used within the index
 * @return (id)
 */
-(nonnull instancetype) initWithName:(nonnull NSString*)columnName;

@end

#define SHARKSYNC_DEFAULT_GROUP @"__default__"

@interface SRKSyncObject : SRKStringObject

- (BOOL)commitInGroup:(nullable NSString*)group;

@end

@protocol SharkSyncDelegate <NSObject>

@required

@end

@class SharkSyncSettings;
@class SharkSyncChanges;

typedef void(^SharkSyncChangesReceived)(SharkSyncChanges* _Nonnull changes, NSError* _Nullable error);

/**
 *  SharkSync.io is a service from the developers of SharkORM which provides a codeless data synchronisation platoform for mobile devices.
 */
@interface SharkSync : NSObject

/** Starts the service with the provided application and access keys which are generated on the SharkSync.io customer portal.  Once the service is started, data will automatically start synchronising between the appliaction and the service.  The application will "subscribe" to certain visibility groups, and data written into that group (in any table) will automatically be distributed to other installations which have also subscribed to the same visibility group.
 */
+ (nullable NSError*)startService;
/** Stops the network calls to pause the framework
 */
+ (void)stopSynchronisation;
/** Provides access to the settings class, so you can set the API keys and change default polling times etc.
 */
+ (nonnull SharkSyncSettings*)Settings;
/** If set, this block gets called after a successful sync operation where changes were downloaded and written to the datastore.  The block is called with the changes as a Change Object and an error if there was a prolem talking to the service.
 */
+ (void)setChangeNotification:(SharkSyncChangesReceived)changeBlock;
// group management
/** Adds a new visibility group into the registry.  That group will then be synchronised with the service from that moment on.
 *  @param visibilityGroup, the visibility group that is to be added to the device.
 *  @param frequency, the time in seconds that a group should be polled for synchronisation.  Enables tiering of frequent and infrequent data.
 */
+ (void)addVisibilityGroup:(nonnull NSString*)visibilityGroup freqency:(int)frequency;
/** Removes a visibility group from the device. Note:  All records belonging to that group will be removed from the device.
 *  @param visibilityGroup, the visibility group that is to be removed from the device.
 */
+ (void)removeVisibilityGroup:(nonnull NSString*)visibilityGroup;
/** Lists the current Visibility Groups which are being synchronised
 */
+ (nonnull NSArray<NSString*>*)currentVisibilityGroups;

@end

typedef NSString* _Nullable(^SharkSyncEncryptionBlock)(NSString* _Nonnull stringValueEncrypt);
typedef NSString* _Nullable(^SharkSyncDecryptionBlock)(NSString* _Nonnull stringValueDecrypt);

@interface SharkSyncSettings : NSObject

/** Specifies a block to be used to encrypt the data before transmission to the service, accepts data and returns encrypted data.  The default block if one is not specified is an AES256 implementation which uses the aes256EncryptionKey property as a key.
 */
@property (copy, nullable)    SharkSyncEncryptionBlock encryptBlock;
/** Specifies a block to be used to decrypt the data received from the service, accepts data and returns decrypted data.  The default block if one is not specified is an AES256 implementation which uses the aes256EncryptionKey property as a key.
 */
@property (copy, nullable)    SharkSyncDecryptionBlock decryptBlock;
/** The encryption key used to encrypt/decrypt data using the default AES256 algo utilised by the framework.
 */
@property (strong, nullable)  NSString* aes256EncryptionKey;

/** The service endpoint if self hosting.
 */
@property (strong, nonnull)  NSString* serviceUrl;

/** The interval at which to poll for group changes, for the default group & any groups with a frequency of 0.
 */
@property int defaultPollInterval;

/** The application key generated by the admin console at SharkSync.io
 */
@property (strong, nullable) NSString* applicationKey;
/** You account key as generated as SharkSync.io
 */
@property (strong, nullable) NSString* accountKey;
/** You can specify a device identifier, useful for debugging issues with the service.
 */
@property (strong, nullable) NSString* deviceId;

/** When true, if a record is committed into a group to which the device is not subscribed the device will automatically register for that new group.
 */
@property BOOL      autoSubscribeToGroupsWhenCommiting;

/** Additional dedfault values to be posted to the API service with every call
 */
@property (strong, nonnull) NSMutableDictionary* defaultPostValues;

@end


@interface SharkSyncChanges : NSObject

/** entities returns an array of the entitiy names that were modified during the recent synchronisation request
 */
- (NSArray<NSString*>*)entities;
/** returns the primary key values which were modified for a particular entity
 */
- (NSArray<NSString*>*)primaryKeysForEntity:(NSString*)entity;

@end

#endif













