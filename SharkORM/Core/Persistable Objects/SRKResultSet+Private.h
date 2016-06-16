//
//  SRKResultSet+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef DBResultSet_Private_h
#define DBResultSet_Private_h

@interface SRKResultSet () {
	NSArray *					_arrayStore;
	NSArray *					_arrayRecordPrimaryKeys;
	NSMutableDictionary *		_dictionaryStore;
	UInt64						_batchSize;
	UInt64						_batchPosition;
	NSUInteger					_size;
	SRKQuery*					_query;
}

- (instancetype)initWithArrayOfPrimaryKeys:(NSArray *)array andQuery:(SRKQuery*)query;

@end

#endif /* DBResultSet_Private_h */
