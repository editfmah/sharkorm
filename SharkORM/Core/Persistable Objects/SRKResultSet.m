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


#import "SharkORM.h"
#import "SRKQuery+Private.h"
#import "SRKResultSet+Private.h"
#import "SRKJoinObject.h"


@implementation SRKResultSet

- (id) init
{
	self = [super init];
	if (self != nil) {
		_arrayStore = [NSArray new];
		_size = 0;
	}
	return self;
}

- (instancetype)initWithArray:(NSArray *)array {
	self = [super init];
	if (self != nil) {
		_arrayStore = array;
		_size = array.count;
	}
	return self;
}

- (instancetype)initWithArrayOfPrimaryKeys:(NSArray *)array andQuery:(SRKQuery*)query {
	self = [super init];
	if (self != nil) {
		_query = query;
        _size = array.count;
        _arrayRecordPrimaryKeys = array;
        _dictionaryStore = [NSMutableDictionary new];
	}
	return self;
}

- (void) dealloc
{
	_arrayStore = nil;
	_arrayRecordPrimaryKeys = nil;
	_dictionaryStore = nil;
}

#pragma mark NSArray

-(NSUInteger)count
{
	return _size;
}

-(id)objectAtIndex:(NSUInteger)index
{
	if (!_query.batchSize) {
		return [_arrayStore objectAtIndex:index];
	} else {
		
		@autoreleasepool {
			/* lookup to see if the index is present in the dictionary store */
			id object = [_dictionaryStore objectForKey:@(index)];
			if (!object) {
				
				/* we need to load this batch into the store, to do this we simply go straight over the top of the existing data */
				[_dictionaryStore removeAllObjects];
				
				/* perform query to get the results to add into the store */
				NSMutableArray* primaryKeysToRetrieve = [NSMutableArray new];
				for (int i=@(index).intValue; i < _size; i++) {
					[primaryKeysToRetrieve addObject:[_arrayRecordPrimaryKeys objectAtIndex:i]];
					if (primaryKeysToRetrieve.count == _query.batchSize) {
						break;
					}
				}
				
				SRKQuery* query = [_query.classDecl query];
				query = [query whereWithFormat:@"Id IN (%@)", primaryKeysToRetrieve];
				
				if (_query.joins.count) {
					for (SRKJoinObject* join in _query.joins) {
						query = [query joinTo:join.joinOn leftParameter:join.joinLeft targetParameter:join.joinRight];
					}
				}
				
				if (_query.domainToBeAppended) {
					query = [query domain:_query.domainToBeAppended];
				}
				
				if (_query.orderBy) {
					query = [query orderBy:_query.orderBy];
				}
				
				SRKResultSet* results = nil;
				if (!_query.lightweightObject) {
					results = [query fetch];
				} else if (_query.prefetch) {
					results = [query fetchLightweightPrefetchingProperties:_query.prefetch];
				} else {
					results = [query fetchLightweight];
				}
				
				/* now we check-in the results into the dictionary, ready to be retuned to the call */
				NSUInteger position = index;
				for (SRKObject* o in results) {
					[_dictionaryStore setObject:o forKey:@(position)];
					position++;
				}
				
				object = [_dictionaryStore objectForKey:@(index)];
				
			}
			
			return object;
		}
		
	}
	
}

- (id)firstObject {
	id o = nil;
	if (self.count) {
		o = [self objectAtIndex:0];
	}
	return o;
}

- (BOOL)removeAll {
	
    __block BOOL succeeded = YES;
    
    [SRKTransaction transaction:^{
        
        for (SRKObject* o in self) {
            @autoreleasepool {
                [o remove];
            }
        }
        
    } withRollback:^{
        
        succeeded = NO;
        
    }];
    
    return succeeded;
	
}

@end
