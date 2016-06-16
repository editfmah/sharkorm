//
//  FTSRegistry.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "FTSRegistry.h"

@implementation FTSRegistry

@dynamic tableName, columns, uptodate;

+ (NSDictionary *)defaultValuesForEntity {
	return @{@"uptodate" : @(0)};
}

+ (SRKIndexDefinition *)indexDefinitionForEntity {
	SRKIndexDefinition* idx = [SRKIndexDefinition new];
	[idx addIndexForProperty:@"tablename" propertyOrder:SRKIndexSortOrderNoCase];
	return idx;
}

+ (FTSRegistry *)registryForTable:(NSString *)tableName {
	return [[[[FTSRegistry query] whereWithFormat:@"tablename = %@", tableName] limit:1] fetch].firstObject;
}

+ (BOOL)readyForAction:(NSString *)tableName {
	return [FTSRegistry registryForTable:tableName].uptodate;
}

@end
