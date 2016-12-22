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

#ifndef SRKObject_Private_h
#define SRKObject_Private_h

#import "SharkORM.h"
#import "SRKTransactionInfo.h"

@class SRKObject;
@class SRKObjectChain;

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
@property BOOL                                          dirty;
@property BOOL                                          isLightweightObject;
@property BOOL                                          isLightweightObjectLoaded;
@property (nonatomic, strong)   NSMutableDictionary*    embeddedEntities; // this will be used to store all of the set entities
@property (nonatomic, weak)     id<SRKEventDelegate>    eventsDelegate;
@property (nonatomic, weak)     SRKContext*             context;
@property BOOL                                          isMarkedForDeletion;
@property (strong) NSArray*                             creatorFunctionName;
@property (strong) SRKTransactionInfo*                  transactionInfo;

// methods for data access
- (NSObject*)getField:(NSString*)fieldName;
- (void)setFieldRaw:(NSString*)fieldName value:(NSObject*)value;
- (void)setField:(NSString*)fieldName value:(NSObject*)value;
- (void)setJoinedField:(NSString*)fieldName value:(NSObject*)value;
- (NSArray*)fieldNames;
- (NSArray*)modifiedFieldNames;
- (NSDictionary*)entityDictionary;
- (NSMutableDictionary*)entityContentsAsObjects;
- (void)rawSetManagedObjectDomain:(NSString *)domain;
- (NSString*)managedObjectDomain;
- (void)setManagedObjectDomain:(NSString *)domain;

// events
- (void)triggerInternalEvent:(SRKEvent*)e;
- (void)notifyObjectChanges:(SRKEvent*)e;

// database functions
- (void)setBase; // used commit the changed values into the _fieldValues dictionary e.g. on init of null container and also after save
- (void)rollback;

/* transformation */
- (id)transformInto:(id)targetObject;
- (id)copy;
- (BOOL)__commitRawWithObjectChain:(SRKObjectChain*)chain;
- (BOOL)__removeRaw;
- (void)reloadRelationships;

/* schema */
+(int)getEntityPropertyType:(NSString*)propertyName;
+(int)getEntityPropertyType:(NSString*)propertyName forClass:(Class)entityClass;

@end

#endif /* SRKObject_Private_h */
