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



#import "SRKFuzzyStore.h"
#import "SharkORM.h"
#import <CommonCrypto/CommonCrypto.h>

/* fuzzy store */

// SRKObjects


//store
@interface __FuzzyStore : SRKObject

@property (strong)  NSString*       identifier;
@property (strong)  NSDate*         created;
@property (strong)  NSDate*         modified;

@end

// object
@interface __FuzzyObject : SRKObject

@property (strong)  __FuzzyStore*   store;
@property (strong)  NSString*       hash;
@property (strong)  id              object;

@end

// tags
@interface __FuzzyTags : SRKObject

@property (strong)  __FuzzyStore*   store;
@property (strong)  NSString*       tag;

@end

@interface NSData (NSHash_AdditionalHashingAlgorithms)

- (NSData*) MD5;

- (NSData*) SHA1;

- (NSData*) SHA256;

@end

@implementation NSData (NSHash_AdditionalHashingAlgorithms)

- (NSData*) MD5 {
	unsigned int outputLength = CC_MD5_DIGEST_LENGTH;
	unsigned char output[outputLength];
	
	CC_MD5(self.bytes, (unsigned int) self.length, output);
	return [NSMutableData dataWithBytes:output length:outputLength];
}

- (NSData*) SHA1 {
	unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
	unsigned char output[outputLength];
	
	CC_SHA1(self.bytes, (unsigned int) self.length, output);
	return [NSMutableData dataWithBytes:output length:outputLength];
}

- (NSData*) SHA256 {
	unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
	unsigned char output[outputLength];
	
	CC_SHA256(self.bytes, (unsigned int) self.length, output);
	return [NSMutableData dataWithBytes:output length:outputLength];
}

@end

@implementation __FuzzyStore

@dynamic identifier, created, modified;

+ (SRKIndexDefinition *)indexDefinitionForEntity {
	
	SRKIndexDefinition* idx = [SRKIndexDefinition new];
	[idx addIndexForProperty:@"identifier" propertyOrder:SRKIndexSortOrderAscending];
	return idx;
	
}

+ (NSString *)storageDatabaseForClass {
	return @"fuzzystore";
}

- (BOOL)entityWillDelete {
	
	NSArray* results = [[[__FuzzyObject query] whereWithFormat:@"store = %@", self] fetch];
	for (__FuzzyObject* ob in results) {
		[ob remove];
	}
	
	results = [[[__FuzzyTags query] whereWithFormat:@"store = %@", self] fetch];
	for (__FuzzyTags* ob in results) {
		[ob remove];
	}
	
	return YES;
}

- (BOOL)entityWillInsert {
	
	self.modified = [NSDate date];
	self.created = [NSDate date];
	
	return YES;
}

- (BOOL)entityWillUpdate {
	
	self.modified = [NSDate date];
	return YES;
	
}

@end



@implementation __FuzzyObject

@dynamic store, hash, object;

+ (NSString *)storageDatabaseForClass {
	return @"fuzzystore";
}

+ (NSArray *)encryptedPropertiesForClass {
	return @[@"object"];
}

@end


@implementation __FuzzyTags

@dynamic store,tag;

+ (NSString *)storageDatabaseForClass {
	return @"fuzzystore";
}

+ (SRKIndexDefinition *)indexDefinitionForEntity {
	
	SRKIndexDefinition* idx = [SRKIndexDefinition new];
	[idx addIndexForProperty:@"tag" propertyOrder:SRKIndexSortOrderAscending];
	return idx;
	
}

@end


// Fuzzy Store public class

@implementation SRKFuzzyStore

- (id)init {
	self = [super init];
	if (self) {
		
		self.enableRevisions = YES;
		self.maxRevisionsPerObject = 10;
		
	}
	return self;
}

- (void)addObject:(id)object withIdentifier:(NSString*)identifier {
	
	[self addObject:object withIdentifier:identifier andTags:nil];
	
}

- (void)addObject:(id)object withIdentifier:(NSString*)identifier andTags:(NSArray*)tags {
	
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (!store) {
		store = [__FuzzyStore new];
	}
	
	store.identifier = identifier;
	[store commit];
	
	NSMutableData *data = [[NSMutableData alloc]init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
	[archiver encodeObject:object];
	[archiver finishEncoding];
	
	NSData* d = [NSData dataWithData:data];
	
	__FuzzyObject* fObj = [__FuzzyObject new];
	fObj.object = object;
	fObj.hash = [[d SHA256] description];
	fObj.store = store;
	
	[fObj commit];
	
	NSArray* results = [[[__FuzzyTags query] whereWithFormat:@"store = %@", store] fetch];
	for (__FuzzyTags* t in results) {
		[t remove];
	}
	
	if (tags) {
		for (NSString* s in tags) {
			__FuzzyTags* t = [__FuzzyTags new];
			t.store = store;
			t.tag = s;
			[t commit];
		}
	}
	
	// now work out what we want to do with the revisions
	int revs = self.maxRevisionsPerObject;
	if (!self.enableRevisions) {
		revs = 1;
	}
	
	/* now clean up the objects for this store based on the max revs allowed */
	results = [[[[[__FuzzyObject query] whereWithFormat:@"store = %@", store] offset:revs] orderBy:@"Id DESC"] fetch];
	for (__FuzzyObject* o in results) {
		[o remove];
	}
	
}

- (void)removeObjectWithIdentifier:(NSString*)identifier {
	
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (store) {
		[store remove];
	}
	
}

- (id)objectWithIdentifier:(NSString*)identifier {
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (store) {
		NSArray* results = [[[[[__FuzzyObject query] whereWithFormat:@"store = %@", store] limit:1] orderBy:@"Id DESC"] fetch];
		if (results.count > 0) {
			__FuzzyObject* ob = (id)[results objectAtIndex:0];
			return ob.object;
		}
	}
	
	return nil;
	
}

- (NSArray*)objectsWithTags:(NSArray*)tags {
	
	NSMutableArray* objects = [NSMutableArray new];
	NSArray* results = [[[__FuzzyStore query] whereWithFormat:@"Id IN (SELECT DISTINCT store FROM __FuzzyTags WHERE tag IN (%@))", tags] fetch];
	
	if (results.count > 0) {
		for (__FuzzyStore* store in results) {
			__FuzzyObject* ob = [self objectWithIdentifier:store.identifier];
			if (ob) {
				[objects addObject:ob];
			}
		}
	}
	
	return [NSArray arrayWithArray:objects];
	
}

- (NSArray*)allStoredObjects {
	
	NSMutableArray* objects = [NSMutableArray new];
	NSArray* results = [[__FuzzyStore query] fetch];
	
	if (results.count > 0) {
		for (__FuzzyStore* store in results) {
			__FuzzyObject* ob = [self objectWithIdentifier:store.identifier];
			if (ob) {
				[objects addObject:ob];
			}
		}
	}
	
	return [NSArray arrayWithArray:objects];
	
}

// revision methods
- (id)objectWithIdentifier:(NSString*)identifier atRevision:(int)revision {
	
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (store) {
		NSArray* results = [[[[[__FuzzyObject query] whereWithFormat:@"store = %@ AND Id = %i", store, revision] limit:1] orderBy:@"Id DESC"] fetch];
		if (results.count > 0) {
			__FuzzyObject* ob = (id)[results objectAtIndex:0];
			return ob.object;
		}
	}
	
	return nil;
	
}

- (NSArray*)revisionsOfObjectWithIdentifier:(NSString*)identifier {
	
	NSMutableArray* objects = [NSMutableArray new];
	
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (store) {
		NSArray* results = [[[[__FuzzyObject query] whereWithFormat:@"store = %@", store] limit:self.maxRevisionsPerObject] fetch];
		if (results.count > 0) {
			for (__FuzzyObject* ob in results) {
				[objects addObject:ob.Id];
			}
		}
	}
	
	return [NSArray arrayWithArray:objects];
	
}

- (NSDictionary *)infoForObjectWithIdentifier:(NSString *)identifier {
	
	NSMutableDictionary* dInfo = [NSMutableDictionary new];
	
	__FuzzyStore* store = [__FuzzyStore firstMatchOf:@"identifier" withValue:identifier];
	if (store) {
		NSArray* results = [[[[[__FuzzyObject query] whereWithFormat:@"store = %@", store] limit:1] orderBy:@"Id DESC"] fetch];
		if (results.count > 0) {
			__FuzzyObject* ob = (id)[results objectAtIndex:0];
			[dInfo setObject:ob.object forKey:@"object"];
			[dInfo setObject:store.modified forKey:@"modified"];
			[dInfo setObject:store.created forKey:@"created"];
			[dInfo setObject:store.identifier forKey:@"identifier"];
		}
		
		results = [[[__FuzzyTags query] whereWithFormat:@"store = %@", store] fetch];
		[dInfo setObject:[NSArray arrayWithArray:results] forKey:@"tags"];
		[dInfo setObject:[self revisionsOfObjectWithIdentifier:identifier] forKey:@"revisions"];
		
	}
	
	return [NSDictionary dictionaryWithDictionary:dInfo];
	
}

@end