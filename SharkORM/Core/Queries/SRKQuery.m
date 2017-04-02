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



#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SharkORM+Private.h"
#import "SRKQuery+Private.h"
#import "SharkORM+Private.h"
#import "SRKResultSet+Private.h"
#import "SRKQueryAsyncHandler+Private.h"
#import "SRKUtilities.h"
#import "SRKJoinObject.h"
#import "SRKRegistry.h"
#import "SRKObject+Private.h"
#import "SRKGlobals.h"

@implementation SRKQuery

/* parameter methods */

- (SRKQuery*)where:(NSString*)where {
	self.whereClause = where;
	return self;
}

- (SRKQuery*)whereWithFormat:(NSString*)format withParameters:(NSArray*)params {
	
	/* loop through the arguments and convert the objects into the correct format */
	NSMutableArray * objParams = [NSMutableArray arrayWithArray:params];
	NSMutableArray * arguments = [NSMutableArray array];
	
	NSDictionary* d = [[SRKUtilities new] paramatiseQueryString:format];
	format = [d objectForKey:@"format"];
	NSArray* a = [d objectForKey:@"types"];
	
	int ptr = 0;
	
	if (format)
	{
		
		for(NSString* s in a) {
			
			ptr++;
			
			NSRange currentParamHolder = NSMakeRange(0, 0);
			int pCount = 0;
			const char* fmt = format.UTF8String;
			
			for (int i = 0; i < format.length; i++) {
				if (fmt[i] == '?') {
					pCount++;
				}
				
				if (pCount == ptr) {
					currentParamHolder = NSMakeRange(i, 1);
					break;
				}
				
			}
			
			if([s isEqualToString:@"OBJECT"]) {
				
				id argument = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				
				/* test the object to see if it is a SRKObject and the actual parameter to be extracted is the [Id] value */
				if (!argument) {
					argument = [NSNull null];
				}
				
				/* now work out if the type is an Array or Set */
				if ([argument isKindOfClass:[NSArray class]] || [argument isKindOfClass:[NSSet class]]) {
					
					NSString* placeHolders = @"";
					int setCount = 0;
					
					if ([argument isKindOfClass:[NSArray class]]) {
						
						NSArray* t = (NSArray*)argument;
						setCount = @(t.count).intValue;
						
						for (id obj in t) {
							
							placeHolders = [placeHolders stringByAppendingString:@",?"];
							[arguments addObject:obj];
							
						}
						
					} else {
						
						NSSet* t = (NSSet*)argument;
						setCount = @(t.allObjects.count).intValue;
						
						for (id obj in t.allObjects) {
							
							placeHolders = [placeHolders stringByAppendingString:@",?"];
							[arguments addObject:obj];
							
						}
						
					}
					
					if (placeHolders.length > 0) {
						
						placeHolders = [placeHolders substringFromIndex:1];
						format = [format stringByReplacingCharactersInRange:currentParamHolder withString:placeHolders];
						ptr += setCount - 1;
						
					} else {
						
						/* there were no items in the set or array */
						[arguments addObject:[NSNull null]];
						
					}
					
				} else {
					
					[arguments addObject:argument];
					
				}
				
			} else if ([s isEqualToString:@"INT"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"FLOAT"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"UINT"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"STRING"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"LONG"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"FLOAT"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			} else if ([s isEqualToString:@"DOUBLE"]) {
				
				NSNumber* numVal = [objParams objectAtIndex:0];
				[objParams removeObjectAtIndex:0];
				[arguments addObject:numVal];
				
			}
			
		}
		
	}
	
	self.whereClause = format;
	self.parameters = [NSArray arrayWithArray:arguments];
	
	return self;
	
}

- (SRKQuery*)whereWithFormat:(NSString*)format,... {
	
	/* loop through the arguments and convert the objects into the correct format */
	NSMutableArray * arguments = [NSMutableArray array];
	
	NSDictionary* d = [[SRKUtilities new] paramatiseQueryString:format];
	format = [d objectForKey:@"format"];
	NSArray* a = [d objectForKey:@"types"];
	
	int ptr = 0;
	
	if (format)
	{
		
		va_list objectList;
		va_start(objectList, format);
		
		for(NSString* s in a) {
			
			ptr++;
			
			NSRange currentParamHolder = NSMakeRange(0, 0);
			int pCount = 0;
			
			const char* fmt = format.UTF8String;
			
			for (int i = 0; i < format.length; i++) {
				if (fmt[i] == '?') {
					pCount++;
				}
				
				if (pCount == ptr) {
					currentParamHolder = NSMakeRange(i, 1);
					break;
				}
				
			}
			
			if([s isEqualToString:@"OBJECT"]) {
				
				id argument = va_arg(objectList, id);
				
				/* test the object to see if it is a SRKObject and the actual parameter to be extracted is the [Id] value */
				if (!argument) {
					argument = [NSNull null];
				}
				
				/* now work out if the type is an Array or Set */
				if ([argument isKindOfClass:[NSArray class]] || [argument isKindOfClass:[NSSet class]]) {
					
					NSString* placeHolders = @"";
					int setCount = 0;
					
					if ([argument isKindOfClass:[NSArray class]]) {
						
						NSArray* t = (NSArray*)argument;
						setCount = @(t.count).intValue;
						
						for (id obj in t) {
							
							placeHolders = [placeHolders stringByAppendingString:@",?"];
							[arguments addObject:obj];
							
						}
						
					} else {
						
						NSSet* t = (NSSet*)argument;
						setCount = @(t.allObjects.count).intValue;
						
						for (id obj in t.allObjects) {
							
							placeHolders = [placeHolders stringByAppendingString:@",?"];
							[arguments addObject:obj];
							
						}
						
					}
					
					if (placeHolders.length > 0) {
						
						placeHolders = [placeHolders substringFromIndex:1];
						format = [format stringByReplacingCharactersInRange:currentParamHolder withString:placeHolders];
						ptr += setCount - 1;
						
					} else {
						
						/* there were no items in the set or array */
						[arguments addObject:[NSNull null]];
						
					}
					
				} else {
					
					[arguments addObject:argument];
					
				}
				
			} else if ([s isEqualToString:@"INT"]) {
				
				int argument = va_arg(objectList, int);
				[arguments addObject:[NSNumber numberWithInt:argument]];
				
			} else if ([s isEqualToString:@"FLOAT"]) {
				
				float argument = va_arg(objectList, double);
				[arguments addObject:[NSNumber numberWithFloat:argument]];
				
			} else if ([s isEqualToString:@"UINT"]) {
				
				unsigned int argument = va_arg(objectList, unsigned int);
				[arguments addObject:[NSNumber numberWithUnsignedInt:argument]];
				
			} else if ([s isEqualToString:@"STRING"]) {
				
				const char* argument = va_arg(objectList, const char*);
				[arguments addObject:[NSString stringWithUTF8String:argument]];
				
			} else if ([s isEqualToString:@"LONG"]) {
				
				long argument = va_arg(objectList, long);
				[arguments addObject:[NSNumber numberWithLong:argument]];
				
			} else if ([s isEqualToString:@"FLOAT"]) {
				
				float argument = va_arg(objectList, double);
				[arguments addObject:[NSNumber numberWithFloat:argument]];
				
			} else if ([s isEqualToString:@"DOUBLE"]) {
				
				double argument = va_arg(objectList, double);
				[arguments addObject:[NSNumber numberWithDouble:argument]];
				
			}
			
		}
		
		va_end(objectList);
	}
	
	self.whereClause = format;
	self.parameters = [NSArray arrayWithArray:arguments];
	
	return self;
	
}

- (SRKQuery*)limit:(int)limit {
	self.limitOf = limit;
	return self;
}

- (SRKQuery*)orderBy:(NSString*)order {
    if ([self.orderBy isEqualToString:SRK_DEFAULT_ORDER]) {
        self.orderBy = order;
    } else {
        // we need to append this ORDER BY to an existing one
        self.orderBy = [NSString stringWithFormat:@"%@,%@", self.orderBy, order];
    }
	
	return self;
}

- (SRKQuery*)orderByDescending:(NSString*)order {
    if ([self.orderBy isEqualToString:SRK_DEFAULT_ORDER]) {
        self.orderBy = [order stringByAppendingString:@" DESC"];
    } else {
        // we need to append this ORDER BY to an existing one
        self.orderBy = [NSString stringWithFormat:@"%@,%@", self.orderBy, [order stringByAppendingString:@" DESC"]];
    }
	return self;
}

- (SRKQuery*)offset:(int)offset {
	self.offsetFrom = offset;
	return self;
}

- (SRKQuery*)batchSize:(int)batchSize {
	self.batchSize = batchSize;
	return self;
}

- (SRKQuery *)domain:(NSString *)domain {
	self.domainToBeAppended = domain;
	return self;
}

- (SRKQuery*)joinTo:(Class)joinClass leftParameter:(NSString*)leftParameter targetParameter:(NSString*)targetParameter {
	
    // check to see if the 'left parameter' is actually a fully qualified field label such as "Department.location", if so this could be using the result of a previous join to join to a subsequent table.  But even if xxxxxx.fieldname is == to self.class it doesn't matter.  Do the same for the right.
    
    NSString* fromEntityClass = [self.classDecl description];
    NSString* toEntityClass = [joinClass description];
    
    NSString* completeLeftParameter = @"";
    
    if (![leftParameter containsString:@"."]) {
        completeLeftParameter = [NSString stringWithFormat:@"%@.%@", fromEntityClass, leftParameter];
    } else {
        completeLeftParameter = leftParameter;
    }
    
    NSString* completeRightParameter = @"";
    
    if (![targetParameter containsString:@"."]) {
        completeRightParameter = [NSString stringWithFormat:@"%@.%@", toEntityClass, targetParameter];
    } else {
        completeRightParameter = targetParameter;
    }
    
    SRKJoinObject* join = [[SRKJoinObject new] setJoinOn:joinClass joinWhere:[NSString stringWithFormat:@"%@ = %@", completeLeftParameter, completeRightParameter] joinLeft:leftParameter joinRight:targetParameter];
    
    [self.joins addObject:join];
    
	
	
	return self;
}

/* execution methods */

- (id)fetchSpecificValueWithQuery:(NSString *)query {
 
	return [SharkORM getValueFromQuery:query inClass:self.classDecl];
	
}

- (SRKResultSet*)fetch {
	
	/* look to see if this request is a FTS query, if so change the restrictions to focus on the fts table */
	/* the original query may look like name MATCH 'adrian', but these object will be in an fts_ table */
	if (self.fts) {
		/*
		 check to see if this object is actually an FTS object and someone isn't using the wrong query type.
		 */
		if (![self.classDecl FTSParametersForEntity]) {
			SRKError* err = [SRKError new];
			err.errorMessage = [NSString stringWithFormat:@"You have attempted to query the class '%@' using the fts (Full Text Search) query object.  But this class does not implement the 'FTSParametersForEntity' method, so the query returned no results.", self.classDecl];
			
			if ([[[SRKGlobals sharedObject] delegate] respondsToSelector:@selector(databaseError:)]) {
				[[[SRKGlobals sharedObject] delegate] performSelector:@selector(databaseError:) withObject:err];
			}
			return [SRKResultSet new]; /* no results, as no FTS objects to query */
		}
		self.whereClause = [NSString stringWithFormat:@"Id IN (SELECT docid FROM fts_%@ WHERE %@)", [self.classDecl description], self.whereClause];
	}
	
	if (!self.batchSize) {
		
		NSArray* results = [[SharkORM new] fetchEntitySetForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		[[SRKRegistry sharedInstance] add:results intoDomain:self.domainToBeAppended];
		return [[SRKResultSet alloc] initWithArray:results];
		
	} else {
		
		/* batch objects, require a query for the Id values only */
		
		NSArray* results = [[SharkORM new] fetchIDsForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		return [[SRKResultSet alloc] initWithArrayOfPrimaryKeys:results andQuery:self];
		
	}
	
}

- (SRKResultSet*)fetchLightweight {
	
	self.lightweightObject = YES;
	
	if (!self.batchSize) {
		
		NSArray* results = [[SharkORM new] fetchEntitySetForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		[[SRKRegistry sharedInstance] add:results intoDomain:self.domainToBeAppended];
		return [[SRKResultSet alloc] initWithArray:results];
		
	} else {
		
		/* batch objects, require a query for the Id values only */
		
		NSArray* results = [[SharkORM new] fetchIDsForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		return [[SRKResultSet alloc] initWithArrayOfPrimaryKeys:results andQuery:self];
		
	}
	
}

- (SRKResultSet*)fetchLightweightPrefetchingProperties:(NSArray *)properties {
	
	self.prefetch = properties;
	self.lightweightObject = YES;
	
	if (!self.batchSize) {
		
		NSArray* results = [[SharkORM new] fetchEntitySetForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		return [[SRKResultSet alloc] initWithArray:results];
		
	} else {
		
		/* batch objects, require a query for the Id values only */
		
		NSArray* results = [[SharkORM new] fetchIDsForQuery:self];
		if (!results.count) {
			return [SRKResultSet new];
		}
		return [[SRKResultSet alloc] initWithArrayOfPrimaryKeys:results andQuery:self];
		
	}
	
}

- (SRKQueryAsyncHandler *)fetchAsync:(__autoreleasing SRKQueryAsyncResponse)_responseBlock {
	
	SRKQueryAsyncHandler* hnd = [[SRKQueryAsyncHandler alloc] initWithQuery:self andAsyncBlock:_responseBlock];
	return hnd;
	
}

- (SRKQueryAsyncHandler *)fetchAsync:(__autoreleasing SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread {
	
	SRKQueryAsyncHandler* hnd = [[SRKQueryAsyncHandler alloc] initWithQuery:self andAsyncBlock:_responseBlock];
	hnd.onMainThread = onMainThread;
	return hnd;
	
}

- (SRKQueryAsyncHandler *)fetchLightweightAsync:(SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread {
	
	self.lightweightObject = YES;
	SRKQueryAsyncHandler* hnd = [[SRKQueryAsyncHandler alloc] initWithQuery:self andAsyncBlock:_responseBlock];
	hnd.onMainThread = onMainThread;
	return hnd;
	
}

- (SRKQueryAsyncHandler *)fetchLightweightPrefetchingPropertiesAsync:(NSArray *)properties withAsyncBlock:(SRKQueryAsyncResponse)_responseBlock onMainThread:(BOOL)onMainThread {
	
	self.prefetch = properties;
	self.lightweightObject = YES;
	SRKQueryAsyncHandler* hnd = [[SRKQueryAsyncHandler alloc] initWithQuery:self andAsyncBlock:_responseBlock];
	hnd.onMainThread = onMainThread;
	return hnd;
	
}

- (NSArray*)ids {
	
	return [[SharkORM new] fetchIDsForQuery:self];
	
}

- (NSArray*)fetchWithContext {
	
	SRKContext* context = [SRKContext new];
	NSArray* entitys = [self fetch];
	for (SRKObject* o in entitys) {
		o.context = context;
		[context addEntityToContext:o];
	}
	return entitys;
	
}

- (NSArray*)fetchIntoContext:(SRKContext*)context {
	
	NSArray* entitys = [self fetch];
	for (SRKObject* o in entitys) {
		o.context = context;
		[context addEntityToContext:o];
	}
	return entitys;
	
}

- (NSDictionary*)groupBy:(NSString*)propertyName {
	
	/* this, in time, will need to be put into sql to do the grouping but for now ....... */
	NSMutableDictionary* resultsSet = [[NSMutableDictionary alloc] init];
	SRKResultSet* queryResult = [self fetch];
	
	for (SRKObject* g in queryResult) {
		
		NSString* keyValue = (NSString*)[g getField:propertyName];
		if (keyValue) {
			
			NSMutableArray* currentSet = [resultsSet objectForKey:keyValue];
			if (!currentSet) {
				currentSet = [[NSMutableArray alloc] init];
				[resultsSet setObject:currentSet forKey:keyValue];
			}
			
			[currentSet addObject:g];
			
		}
		
	}
	
	return resultsSet;
	
}

- (uint64_t)count {
	
	return [[SharkORM new] fetchCountForQuery:self];
	
}

- (double)sumOf:(NSString*)propertyName {
	
	return [[SharkORM new] fetchSumForQuery:self field:propertyName];
	
}

- (NSArray *)distinct:(NSString *)propertyName {
	
	return [[SharkORM new] fetchDistinctForQuery:self field:propertyName];
	
}

- (SRKQuery*)entityclass:(Class)entityClass {
	
	if ([entityClass isSubclassOfClass:[SRKObject class]]) {
		if ([entityClass conformsToProtocol:@protocol(SRKPartialClassDelegate)]) {
			
			Class fullClass = [entityClass classIsPartialImplementationOfClass];
			if (fullClass) {
				entityClass = fullClass;
			}
			
		}
	}
	
	self.classDecl = entityClass;
	return self;
}

- (id)init {
	self = [super init];
	if (self) {
		self.classDecl = nil;
		self.limitOf = SRK_DEFAULT_LIMIT;
		self.whereClause = SRK_DEFAULT_CONDITION;
		self.offsetFrom = SRK_DEFAULT_OFFSET;
		self.orderBy = SRK_DEFAULT_ORDER;
		self.parameters = nil;
		self.domainToBeAppended = nil;
		self.joins = [NSMutableArray new];
		if ([SharkORM getSettings].defaultManagedObjects) {
			self.domainToBeAppended = [SharkORM getSettings].defaultObjectDomain;
		}
	}
	return self;
}

@end
