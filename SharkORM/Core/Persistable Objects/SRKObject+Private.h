//
//  SRKObject+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKObject_Private_h
#define SRKObject_Private_h

#import "SharkORM.h"

@class SRKObject;

@interface SRKObject () {
	NSString*               managedObjectDomain;
	BOOL					writingPreCalculated;
}

@property BOOL                                          flaggedAsAlive;
@property (nonatomic, strong)   NSMutableArray*         registeredEventBlocks;
@property (nonatomic, strong)   NSMutableDictionary*    fieldData;
@property (atomic, strong)		NSMutableDictionary*    preCalculated;
@property (nonatomic, strong)   NSMutableDictionary*    joinedData;
@property (nonatomic, strong)   NSMutableDictionary*    changedValues;
@property (nonatomic, strong)   NSMutableDictionary*    dirtyFields;
@property BOOL                                          sterilised;
@property BOOL                                          exists;
@property BOOL                                          isLightweightObject;
@property BOOL                                          isLightweightObjectLoaded;
@property (nonatomic, strong)   NSMutableDictionary*    embeddedEntities; // this will be used to store all of the set entities
@property (nonatomic, weak)     id<SRKEventDelegate>     eventsDelegate;
@property (nonatomic, weak)     SRKContext*              context;
@property BOOL                                          isMarkedForDeletion;
@property (strong) NSArray*                             creatorFunctionName;

// methods for data access
- (NSObject*)getField:(NSString*)fieldName;
- (void)setFieldRaw:(NSString*)fieldName value:(NSObject*)value;
- (void)setField:(NSString*)fieldName value:(NSObject*)value;
- (void)setJoinedField:(NSString*)fieldName value:(NSObject*)value;
- (NSArray*)fieldNames;
- (NSArray*)modifiedFieldNames;
- (NSDictionary*)entityDictionary;
- (void)rawSetManagedObjectDomain:(NSString *)domain;
- (NSString*)managedObjectDomain;
- (void)setManagedObjectDomain:(NSString *)domain;

// events
- (void)triggerInternalEvent:(SRKEvent*)e;
- (void)notifyObjectChanges:(SRKEvent*)e;

// database functions
- (void)setBase; // used commit the changed values into the _fieldValues dictionary e.g. on init of null container and also after save


/* transformation */
- (id)transformInto:(id)targetObject;
- (id)copy;
- (BOOL)__commitRaw;
- (BOOL)__removeRaw;
- (void)reloadRelationships;

@end

#endif /* SRKObject_Private_h */
