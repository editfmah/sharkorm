//    MIT License
//
//    Copyright (c) 2016 SharkSync
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

#define SHARK_DATE              20170402
#define SHARK_VER               2.01.03

#import <Foundation/Foundation.h>
#import <objc/message.h>

/* components of SharkORM, developers only need import this header file */

@class SRKObject;
@class SRKRelationship;
@class SRKEvent;
@class SRKEventHandler;
@class SRKQuery;
@class SRKFTSQuery;
@class SRKTransaction;
@class SRKRawResults;

typedef void(^SRKTransactionBlockBlock)();

/**
 * Called from within a transaction block to manually fail a transaction and cause a rollback.  Example, `SRKFailTransaction();`
 *
 * @return void
 */
void SRKFailTransaction();

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
+ (void)transaction:(SRKTransactionBlockBlock)transaction withRollback:(SRKTransactionBlockBlock)rollback;

@end

/**
 * Create a valid 'LIKE' parameter neatly, SharkORM will then recognise this and construct the correct parameter within the query.

 *
 * @param param The string value that you wish to use within a LIKE condition.
 * @return A newly created string which is formatted as a valid LIKE statement, e.g. @" '%{value}%' ".
 */
NSString* makeLikeParameter(NSString* param);

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
@property (strong) NSString*        sqliteJournalingMode;
/// when TRUE, all objects created will automatically be registered within the default managed object domain, this will save the developer from having to manually add the parameter to any queries or individually to objects.
@property BOOL                      defaultManagedObjects;
/// the default managed object domain used for new objects when defaultManagedObjects is set to TRUE.  If not set, this defaults to "SharkORM.default"
@property (strong)                  NSString* defaultObjectDomain;
/// The folder path that the database file should be created in not including the filename, this must be a valid path capable of being turned into an NSURL.
@property (nonatomic,strong)        NSString* databaseLocation;
/// the filename of the default database file, e.g. "MyApplication".  SharkORM will automatically append ."db" onto the end of the filename.  Not including the path to the file.
@property (nonatomic,strong)        NSString* defaultDatabaseName;
/// this is the AES256 encryption key that is used when properties are specified as encryptable.
@property (strong)                  NSString* encryptionKey;
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
@property  (nonatomic, strong) NSArray* queryPlan;
/// The query that was generated from the SRKQuery object.
@property  (nonatomic, strong) NSString* sqlQuery;
/// The compiled query with teh parameters included.
@property  (nonatomic, strong) NSString* compiledQuery;
/// The resultant output from the query.
@property  (nonatomic, strong) NSObject* resultsSet;

@end

/**
 * Ad error raised by SharkORM, gives you the message from the core, as well as the SQL query that was generated and caused the fault.

 */
@interface SRKError : NSObject

/// The error message that was returned from the core of SharkORM.
@property  (nonatomic, retain)  NSString* errorMessage;
/// The query that caused the error.
@property  (nonatomic, retain)  NSString* sqlQuery;

@end

@protocol SRKDelegate <NSObject>

@optional

/// Retuen a SharkORMSettings* object to override the default settings, this will be asked for on initialization of the first persistable object.
- (SRKSettings*)getCustomSettings;
/// This method is called when the database has been successfully opened.
- (void)databaseOpened;
/// This method is called when an error occours within SharkORM.
- (void)databaseError:(SRKError*)error;
/// This method, if implemented, will profile all queries that are performed within SharkORM.  Use the queryTime property within the SRKQueryProfile* object to filter out only queries that do not meet your performance requirements.
- (void)queryPerformedWithProfile:(SRKQueryProfile*)profile;
/// An object that did not support a valid encoding mechanisum was attempted to be written to the database.  It is therefore passed to the delegate method for encoding.  You must return an NSData object that can be stored and later re-hydrated by a call to "decodeUnsupportedColumnValueForColumn"
- (NSData*)encodeUnsupportedColumnValueForColumn:(NSString*)column inEntity:(NSString*)entity value:(id)value;
/// Previously an object was persistsed that was not supported by SharkORM, and "encodeUnsupportedColumnValueForColumn" was called to encode it into a NSData* object, this metthod will pass back a hydrated object created from the NSData*
- (id)decodeUnsupportedColumnValueForColumn:(NSString*)column inEntity:(NSString*)entity data:(NSData*)value;

@end

/**
 * SharkORM class, always accessed through class methods, there is only ever a single instance of the database engine.
 */

typedef void(^SRKGlobalEventCallback)(SRKObject* entity);

@interface SharkORM : NSObject {
    
}

/**
 * Sets the SRKDelegate object that will be used by SharkORM to gain access to settings and to provide the deleoper with access to feedback.
 *
 * @param aDelegate Must be an initialised object that implements the SRKDelegate protocol.
 * @return void
 */
+(void)setDelegate:(id<SRKDelegate>)aDelegate;
/**
 * Used to pre-create and update any persistable classes, SharkORM by default, will only create or update the schema with objects when they are first referenced.  If there is a requirement to ensure that a collection of classes are created before they are used anywhere then you can use this method.  This is not required in most scenarios.
 *
 * @param (Class)class Array of Class* objects to be initialized
 * @return void
 */
+(void)setupTablesFromClasses:(Class)classDecl,...;
/**
 * Migrates data from an existing CoreData database file into SharkORM, only the supplied object names are converted.  NOTE: If successful, the original file will be removed by the routine.  Existing Objects within the supplied list will be cleared from the database.
 *
 * @param filePath The full path to the CoreData file that needs to be converted.
 * @param tablesToConvert Array of SRKObject class names to convert from the original CoreData file provided.
 * @return void
 */
+(void)migrateFromLegacyCoredataFile:(NSString*)filePath tables:(NSArray*)tablesToConvert;
/**
 * Opens or creates a database file from the given name.
 *
 * @param dbName The name of the database to open or create, this is not the full path to the object. By default the path defaults to the applcations Documents directory. If you wish to modify the path the file will exist in, then you will need to implement the "getCustomSettings" delegate method and return an alternative path.
 * @return void;
 */
+(void)openDatabaseNamed:(NSString*)dbName;
/**
 * Closes a database file of the given name, flushing all caches, and invalidating any objects that are still in use within the system.
 *
 * @return void;
 */
+(void)closeDatabaseNamed:(NSString*)dbName;
/**
 * Performs a free text query and returns the result as a INSERT INTO object.
 *
 * @param (NSString*) The query to be performed.
 * @return (SRKRawResults*);
 */
+(SRKRawResults*)rawQuery:(NSString*)sql;
/**
 * Allows the developer to specify a block to be executed against all INSERT events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any INSERT.
 * @return void;
 */
+(void)setInsertCallbackBlock:(SRKGlobalEventCallback)callback;
/**
 * Allows the developer to specify a block to be executed against all UPDATE events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any UPDATE.
 * @return void;
 */
+(void)setUpdateCallbackBlock:(SRKGlobalEventCallback)callback;
/**
 * Allows the developer to specify a block to be executed against all DELETE events.
 *
 * @param (^SRKGlobalEventCallback) The block to be executed when the ORM has instigated any DELETE.
 * @return void;
 */
+(void)setDeleteCallbackBlock:(SRKGlobalEventCallback)callback;

@end

/*
 *      SRKRelationship
 */

@interface SRKRelationship : NSObject {
    
}

@property Class                             sourceClass;
@property Class                             targetClass;
@property (nonatomic, strong) NSString*     sourceProperty;
@property (nonatomic, strong) NSString*     targetProperty;
@property (nonatomic, strong) NSString*     linkTable;
@property (nonatomic, strong) NSString*     linkSourceField;
@property (nonatomic, strong) NSString*     linkTargetField;
@property (nonatomic, strong) NSString*     entityPropertyName;
@property (nonatomic, strong) NSString*     order;
@property (nonatomic, strong) NSString*     restrictions;
@property int                               relationshipType;

@end

/*
 *      SRKIndexDefinition
 */

enum SRKIndexSortOrder {
    SRKIndexSortOrderAscending = 1,
    SRKIndexSortOrderDescending = 2,
    SRKIndexSortOrderNoCase = 3
    };

/**
 * Used to define a set of indexes within a persitable object.
 */
@interface SRKIndexDefinition : NSObject {
    
}
/**
 * Adds the definition for an index on a given object.
 *
 * @param propertyName The name of the property that you wish to index.
 * @param propertyOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @return void
 */
- (void)addIndexForProperty:(NSString*)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder;
/**
 * Adds a composite index on a given object with a sub index on an additional property.
 *
 * @param propertyName The name of the property that you wish to index.
 * @param propertyOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @param secondaryProperty The name of the second property that you wish to index.
 * @param secondaryOrder The order of the index, specified as a value of enum SRKIndexSortOrder.
 * @return void
 */
- (void)addIndexForProperty:(NSString*)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder secondaryProperty:(NSString*)secProperty secondaryOrder:(enum SRKIndexSortOrder)secOrder;

@end

@protocol SRKPartialClassDelegate

@required
/**
 * If implemented, SharkORM knows that this class is only a partial implementation of an existing SRKObject derrived class.  These objects can be retrieved, but will remain sterile and cannot be commited back into the original table.
 *
 * @return (Class) The original SRKObject derrived class definition on which this object is partially based.
 */
+ (Class)classIsPartialImplementationOfClass;

@end

enum SharkORMEvent {
    SharkORMEventInsert = 1,
    SharkORMEventUpdate = 2,
    SharkORMEventDelete = 4,
};

typedef void(^SRKEventRegistrationBlock)(SRKEvent* event);

/**
 * If implemented, SRKEventDelegate is used to notify an object that an event has been raised within a SRKObject.
 */
@protocol SRKEventDelegate <NSObject>

@required
/**
 * Called when a SRKObject class raises an INSERT, UPDATE or DELETE trigger.  This will only get called after the successful completion of the transaction within the database engine.
 *
 * @param (SRKEvent*)e The event object that was created from the SharkORM event model.
 * @return void
 */
- (void)SRKObjectDidRaiseEvent:(SRKEvent*)e;

@end

/*
 *      SRKResultSet
 */
/**
 * Contains the results from a fetch call to a SRKQuery object.  Subclassed from an NSArray, it contains two extra methods, removeAll & commitAll.  These are optimized to complete within a single transaction.
 */
@interface SRKResultSet : NSArray
/**
 * Removes all objects contained within the array from the database.  This is done within a single transaction to optimize performance.
 *
 * @return BOOL, true if operation was successful.
 */
- (BOOL)removeAll;

@end

/*
 *      SRKContext
 */

typedef     void(^contextExecutionBlock)();

/**
 * SRKContext objects are used to effect bulk operations across single or multiple tables.  You can not call commit on an object that has been added to a context.  Instead you call commit on the context itself, all activities will then be performed within an single transaction. NOTE: all SRKObjects have their own context already, and any activity performed on then is guaranteed to complete in an ATOMIC way.  This style of object management is provided in a legacy manner as this is a method that programmers are largely used to, but it is not a requirement.  SharkORM already groups together operations and performs them in bulk when it can to improve performance, the deleoper does not need to think about this when writing their application.
 */
@interface SRKContext : NSObject
/**
 * Adds an SRKObject to a context.

 *
 * @param (SRKObject*)entity The entity to add to the context.
 * @return void
 */
- (void)addEntityToContext:(SRKObject*)entity;
/**
 * Removes an SRKObject from a context.

 *
 * @param (SRKObject*)entity The entity to be removed from the context.
 * @return void
 */
- (void)removeEntityFromContext:(SRKObject*)entity;
/**
 * Used to test if an object is already a member of this context.

 *
 * @param (SRKObject*)entity The entity to be tested for its presence.
 * @return BOOL returns YES if this object exists in this context.
 */
- (BOOL)isEntityInContext:(SRKObject*)entity;
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
typedef void(^SRKCommitOptionsBlock)();


/**
 * Defines a set of options which will be taken into account on an object by object basis when commiting or removing entities from the data store.  All SRKObjects' have a commit options property, and it is automatically populated with the ORM defaults.
 */
@interface SRKCommitOptions : NSObject

/// when TRUE all embedded/related entitied will be commited along with the originating entity.  Default is TRUE.
@property BOOL                              commitChildObjects;
/// when TRUE event notifications will be raised for any registered handlers attached to the entity.  Default is TRUE.
@property BOOL                              triggerEvents;
/// when populated with an array of child/related entities, these will not be commited or updated when the originating entity is written to or deleted from the data store.  Default is nil.
@property NSArray*                          ignoreEntities;
/// when TRUE errors will be raised within transactions and posted to the app delegate, when false syntax errors will not raise errors and will not fail a transaction block.  Default is TRUE.
@property BOOL                              raiseErrors;
/// when TRUE, the properties of this class object will be reset back to their defaults.  Any blocks that were assigned for post events will also be cleared and their memory released.
@property BOOL                              resetOptionsAfterCommit;
/// executed on the calling thread, after an object has been successfully persisted.
@property (copy) SRKCommitOptionsBlock      postCommitBlock;
/// executed on the calling thread, after an object has been successfully removed.
@property (copy) SRKCommitOptionsBlock      postRemoveBlock;

@end

/*
 *      SRKObject
 *
 */

/**
 * Specifies a persistable class within SharkORM, any properties that are created within a class that is derrived from SRKObject will need to be implemnted using dynamic properties and not synthesized ones.  SharkORM places its own get/set methods to ensure that all values are correct for the storage and column type.

 */
@interface SRKObject : NSObject <NSCopying>

/// Creates a SRKQuery object for this class
+ (SRKQuery*)query;
/// Create a Full Text Search query object for this class
+(SRKQuery*)fts;
/// Returns the first object where th eproperty is matched with value
+ (id)firstMatchOf:(NSString*)property withValue:(id)value;

/// The event object for the entire class.
+ (SRKEventHandler*)eventHandler;

/// The primary key column, this is common and mandatory across all persistable classes.
@property (nonatomic, strong)   NSNumber* Id;

/// Joined data, if set this contains the results of the query from adjoining tables
@property (nonatomic, strong, readonly)   NSDictionary* joinedResults;

/// commit options class of type SRKCommitOptions.  Allows the developer to specify object specific options when commiting and removing entities from the data store.
@property (nonatomic, strong)   SRKCommitOptions* commitOptions;

/**
 * Initialises a new instance of the object, if an object already exists with the specified primary key then you will get that object back, if not you will net a new object with the primary key specified already.
 *
 * @param (NSObject*)priKeyValue The primary key value to look up an existing object
 * @return SRKObject* Either an existing or new class.
 */
- (instancetype)initWithPrimaryKeyValue:(NSObject*)priKeyValue;
/**
 * Returns an object that matches the primary key value specified, if there is no match, nil is returned.
 
 *
 * @param (NSObject*)priKeyValue The primary key value to look up an existing object
 * @return SRKObject* Either an existing object or nil.
 */
+ (instancetype)objectWithPrimaryKeyValue:(NSObject*)priKeyValue;
/**
 * Initialises a new instance of the object, the supplied dictionary will pre-populate the field values.
 *
 * @param (NSDictionary*)initialValues, in the format [<property as string>:<value as Any>]
 * @return SRKObject*.  A new object with the pre-populated values.
 */
- (instancetype)initWithDictionary:(NSDictionary*)initialValues;
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
 * Used to indicate to SharkORM that you wish to create a FTS virtual table using the return values.
 *
 * @return (NSArray*) Return an array of property names, these will be used to create the virtual table, any inserts into the fts table will also automatically contain these values.
 */
+ (NSArray*)FTSParametersForEntity;
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
+ (SRKRelationship*)relationshipForProperty:(NSString*)property;
/**
 * Used to specify the indexes that need to be created and maintained on the given object.

 *
 * @return (SRKIndexDefinition*) return an index object to let SharkORM know which properties need to be indexed for performance reasons.  Primary keys are already indexed, as are any properties that are in fact other persisbale classes.  SharkORM will attempt to automatically calculate indexes from the relationships between your classes, but sometimes you may with to add them manually given feedback form the profiling mechanisum.
 */
+ (SRKIndexDefinition*)indexDefinitionForEntity;
/**
 * Used to indicate to SharkORM that you wish to ignore ceratin properties and to not persiste them.
 *
 * @return (NSArray*) Return an array of property names, these will be used to create an ignore list.
 */
+ (NSArray*)ignoredProperties;
/**
 * Used to specify the default values for a new entity, where the "key" is the property name and the "value" is a standard NSObject such as NSNumber / NSString / NSNull / NSData / NSArray.  Every new object will automatically have these properties set with their default values.  When adding a new property to a SRKObject class, SharkORM will create a new column.  This column will be populated with the default value as provided by this method.
 *
 * @return (NSDictionary*) return a dictionary object to specify default values for properties.
 */
+ (NSDictionary*)defaultValuesForEntity;
/**
 * Specifies the properties on the class that should remain encrypted within the database. NOTE: you will not be able to perform optimised queries on these encrypted properties so they should only be used to encrypt sensitive data that would not normally be searched on.

 *
 * @return and (NSArray*) of property names that SharkORM should keep encrypted in the database.
 */
+ (NSArray*)encryptedPropertiesForClass;
/**
 * Specifies the properties on the class that should be unique within the datastore, before a commit operation is performed a test is made to ensure another record with those exact properties does not already exist.  Commit will return NO/FALSE if there is an existant match.
 *
 * @return and (NSArray*) of property names that SharkORM should test for uniqueness.
 */
+ (NSArray*)uniquePropertiesForClass;
/**
 * Specifies the database file that this particular class will be persisted in.  This enables you to have your persistable classes spanning many different files.

 *
 * @return (NSString*) alternative filename for storage of this class.  This will be created within the same folder as the main database.
 */
+ (NSString*)storageDatabaseForClass;

/* partial classes */
+ (Class)classIsPartialImplementationOfClass;

/* live objects */
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.

 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours, this will be called on the main thread.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.

 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.

 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @param updateSelfWithEvent:(BOOL)updateSelf is used to specify if you wish the object to have its values updated with the changes that raised the event.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread updateSelfWithEvent:(BOOL)updateSelf;
/**
 * Allows an object to become a member of a managed object domain, only objects within the same domain recieve value change notifications.

 * @param setManagedObjectDomain:(NSString*)domain  sets the domain that this object is managed within, idetical objects within the same domain will share property values which are updated when the objects are comitted to the store.
 * @return void
 */
- (void)setManagedObjectDomain:(NSString*)domain;
/**
 * Clears all event blocks within the object and stops the object from receiving event notifications.

 *
 * @return void
 */
- (void)clearAllRegisteredBlocks;

@end

/**
 * Every SRKObject class or instance contains an SRKEventHandler, which the developer can use to monitor activity within the object or class of objects.

 *
 */
@interface SRKEventHandler : NSObject

- (SRKEventHandler*)entityclass:(Class)entityClass;

@property (nonatomic, weak) id<SRKEventDelegate> delegate;
/**
 * Allows the developer to 'hook' into the events that are raised within SharkORM, useful if you wish to be notified when various actions happen within certain tables.

 *
 * @param registerBlockForEvents:(enum SharkORMEvent)events specifies the events that you are looking to observe, these can be SharkORMEventInsert, SharkORMEventUpdate or SharkORMEventDelete.  They are bitwise properties so can be combined such like SharkORMEventInsert|SharkORMEventUpdate.
 * @param withBlock:(SRKEventRegistrationBlock)block is the block to be executed when the event occours.
 * @param onMainThread:(BOOL)mainThread is used to specify if you wish the block to be executed on the main thread or the originating thread of the event.  Useful if you are updating UI componets.
 * @return void
 */
- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread;
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
@interface SRKStringObject : SRKObject <NSCopying>

//NOTE:  There is no way around this, for convenience for the developer to 'know' the type.  The base class inspects the value to check its class, but this is bad OO practice that leads to convenient and nice API for the developer so suck it up, it is NOT dangerous as the public facing API is strongly typed and safe, and well anticipated by the backstore.

/// The primary key column, this is common and mandatory across all persistable classes.  In this case it is forced to NSString* to allow string primary keys in Swift.

@property (nonatomic, strong)   NSString* Id;
#pragma clang diagnostic pop

@end

/**
 * SRKEvent* is an container class, which is passed to event objects as a parameter.

 *
 */
@interface SRKEvent : NSObject

/// The type of event that triggered the creation of this object
@property  enum SharkORMEvent               event;
/// The persistable object that created this event
@property  (nonatomic, weak) SRKObject*      entity;
/// The properties that have changed within this object since its last comital into the database.
@property  (nonatomic, strong) NSArray*     changedProperties;

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

typedef void(^SRKQueryAsyncResponse)(SRKResultSet* results);

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
- (SRKQuery*)where:(NSString*)where;
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.

 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename = %@ ", @"Adrian"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)whereWithFormat:(NSString*)format,...;
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.

 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename = %@ "
 * @param (NSArray*)params is an array of parameters to be placed into the format string, useful for constructing queries through a logic path.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)whereWithFormat:(NSString*)format withParameters:(NSArray*)params;
/**
 * Limits the number of results retuned from the query

 *
 * @param (int)limit the number of results to limit to
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)limit:(int)limit;
/**
 * Specifies the property by which the results will be ordered.  This can contain multiple, comma separated, values.

 *
 * @param (NSString*)order a comma separated string for use to order the results, e.g. "surname, forename"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)orderBy:(NSString*)order;
/**
 * Specifies the property by which the results will be ordered in decending value.  This can contain multiple, comma separated, values.

 *
 * @param (NSString*)order a comma separated string for use to order the results, e.g. "surname, forename"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)orderByDescending:(NSString*)order;
/**
 * Specifies the number of results to skip over before starting the aggregation of the results.

 *
 * @param (int)offset the offset value for the query.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)offset:(int)offset;
/**
 * Specifies the number of results to retrieve in a batch, the SRKResultSet is then created using a batch store co-ordinator.
 *
 * @param (int)batchSize the batch size of the query.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)batchSize:(int)batchSize;
/**
 * Specifies the managed object domain that the query results will be added to.

 *
 * @param (NSString*)domain the domain value as a string, e.g. "network-objects"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)domain:(NSString*)domain;
/**
 * Used to include "joined" data within the query string, you must use the tablename.columnname syntax within a where statement

 *
 * @param (Class)joinTo the class you would like to pwrform a SQL JOIN with
 * @param (NSString*)leftParameter the property name that you would like to use within the local object to match against the target
 * @param (NSString*)targetParameter the property within the class you wish to join with that will be matched with the left parameter.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)joinTo:(Class)joinClass leftParameter:(NSString*)leftParameter targetParameter:(NSString*)targetParameter;

/* execution methods */
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.

 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKResultSet*)fetch;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.

 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKResultSet*)fetchLightweight;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.

 * @param prefetchProperties:(NSArray*) the properties you would like to retieve with the fetch.
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKResultSet*)fetchLightweightPrefetchingProperties:(NSArray*)properties;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.

 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (SRKQueryAsyncHandler*)fetchAsync:(SRKQueryAsyncResponse)_responseBlock;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.

 * @param onMainThread: specify weather you want to execute the results block on the main thread.
 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (SRKQueryAsyncHandler *)fetchAsync:(SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
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
- (SRKQueryAsyncHandler*)fetchLightweightAsync:(SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
/**
 * Performs the query and returns the results, you will always get an object back even if there are no results.  All the objects will be deflated lightweight objects, who's values will only be retrieved upon accessing the properties.  If configured, the object can "hang on" to the object to stop repeat queries, but the objects will then use more memory.

 * @param prefetchProperties:(NSArray*) the properties you would like to retieve with the fetch.
 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKQueryAsyncHandler*)fetchLightweightPrefetchingPropertiesAsync:(NSArray*)properties withAsyncBlock:(SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread;
/**
 * Performs the query as an async operation and returns a handler object. The results are then passed into the supplied SRKQueryAsyncResponse block.

 *
 * @return (SRKQueryAsyncHandler*) an async query handler to allow the cancellation of the fetch request.
 */
- (NSArray*)ids;
/**
 * Performs the query and returns the results all within the same SRKContext, you will always get an object back even if there are no results.

 *
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKResultSet*)fetchWithContext;
/**
 * Performs the query and returns the results all within the SRKContext specified in the context parameter, you will always get an object back even if there are no results.

 * @param (SRKContext*)context specifies the context that all the results should be added to.
 * @return (SRKResultSet*) results of the query.  Always returns an object and never returns nil.
 */
- (SRKResultSet*)fetchIntoContext:(SRKContext*)context;
/**
 * Performs the query and returns the results grouped by the specified property, you will always get an object back even if there are no results.

 * @param (NSString*)propertyName the property name to group by
 * @return (NSDictionary*) results of the query, the key values are the distinct values of the paramater that was specified.
 */
- (NSDictionary*)groupBy:(NSString*)propertyName;
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
- (NSArray*)distinct:(NSString*)propertyName;

/**
 * Performs the query and returns the sum of the numeric property that is specified in the parameter.
 * @param (NSString*)propertyName the property name to perform the SUM aggregation function on.
 * @return (double)  sum of the specified parameter across all results.
 */
- (double)sumOf:(NSString*)propertyName;

@end

/**
 * A SRKFTS class is used to construct a Full Text Search object and return results from the virtual table.
 *
 *
 */
@interface SRKFTSQuery : SRKQuery

/* parameter methods */
/**
 * Specifies the WHERE clause of the full text search query statement
 *
 * @param (NSString*)where contains the parameters for the query, e.g. " forename MATCH 'Adrian' "
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)where:(NSString*)where;
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.
 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename MATCH %@ ", @"Adrian"
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)whereWithFormat:(NSString*)format,...;
/**
 * Specifies the WHERE clause of the query statement, using a standard format string.
 *
 * @param (NSString*)where contains the parameters for the query, e.g. where:@" forename MATCH %@ "
 * @param (NSArray*)params is an array of parameters to be placed into the format string, useful for constructing queries through a logic path.
 * @return (SRKQuery*) this value can be discarded or used to nest queries together to form clear and concise statements.
 */
- (SRKQuery*)whereWithFormat:(NSString*)format withParameters:(NSArray*)params;

@end

/**
 * A SRKRawResults class is used to store results from raw queries.
 *
 *
 */
@interface SRKRawResults : NSObject

@property (nonatomic) NSMutableArray* rawResults;
@property (nonatomic) SRKError* error;

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
- (id)valueForColumn:(NSString*)columnName atRow:(NSInteger)index;
/**
 * Retrieves a column from the dataset, given the index.
 *
 * @param (NSInteger)index. The index for the column name to retrieve.
 * @return (NSString*), the column name to be used in queries.
 */
- (NSString*)columnNameForIndex:(NSInteger)index;

@end

#endif













