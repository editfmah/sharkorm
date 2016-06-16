//
//  SRKIndex+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKIndex_Private_h
#define SRKIndex_Private_h

@interface SRKIndexDefinition () {
	NSMutableArray* _components;
}

- (void)generateIndexesForTable:(NSString*)tableName inDatabase:(NSString*)dbName;

@end

#endif /* SRKIndex_Private_h */
