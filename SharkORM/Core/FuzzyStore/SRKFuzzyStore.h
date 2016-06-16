//
//  SRKFuzzyStore.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

/* Fuzzy Store */
/**
 * SRKFuzzyStore is a high performance key/value store with tagging, grouping and revisions.
 
 */
@interface SRKFuzzyStore : NSObject
/// Enable revisioning of stored objects
@property BOOL  enableRevisions;
/// The maximum number of revisions to store against a key
@property int   maxRevisionsPerObject;
/**
 * Adds an object to the store with a reference.
 
 *
 * @param (id)object the object to store
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @return void
 */
- (void)addObject:(id)object withIdentifier:(NSString*)identifier;
/**
 * Adds an object to the store with a reference and an array of tags with which to query for items.
 
 *
 * @param (id)object the object to store
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @param (NSArray*)tags tags to categorize the stored object
 * @return void
 */
- (void)addObject:(id)object withIdentifier:(NSString*)identifier andTags:(NSArray*)tags;
/**
 * Removes an object from the store with a matching reference.
 
 *
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @return void
 */
- (void)removeObjectWithIdentifier:(NSString*)identifier;
/**
 * Retrieves an object from the store with a matching reference.
 
 *
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @return id the original object that was given to the store
 */
- (id)objectWithIdentifier:(NSString*)identifier;
/**
 * Retrieves objects from the store with a matching tags.
 
 *
 * @param (NSArray*)tags the tags that will be used to match against objects
 * @return (NSArray*) all matches
 */
- (NSArray*)objectsWithTags:(NSArray*)tags;
/**
 * Retrieves all objects from the store.
 
 *
 * @return (NSArray*)
 */
- (NSArray*)allStoredObjects;

// revision methods
/**
 * Retrieves an object from the store with a matching reference at a specific revision.
 
 *
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @param (int)revision the revision at which to retrieve a stored object
 * @return id the original object that was given to the store
 */
- (id)objectWithIdentifier:(NSString*)identifier atRevision:(int)revision;
/**
 * Retrieves all revisions for a specific object from the store.
 
 * @param (NSString*)identifier identifier to retireve revisions for
 * @return (NSArray*) array of revisions
 */
- (NSArray*)revisionsOfObjectWithIdentifier:(NSString*)identifier;

// info methods
/**
 * Retrieves information about an object from the store with a matching reference.
 
 *
 * @param (NSString*)identifier the reference identifier used to reference the object
 * @return (NSDictionary*) information held about a specific object
 */
- (NSDictionary*)infoForObjectWithIdentifier:(NSString*)identifier;

@end

