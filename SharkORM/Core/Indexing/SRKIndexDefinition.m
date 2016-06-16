//
//  SRKIndex.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SRKIndexDefinition+Private.h"
#import "SharkORM+Private.h"

@implementation SRKIndexDefinition

- (void)addIndexForProperty:(NSString *)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder {
	
	if (!_components) {
		_components = [NSMutableArray new];
	}
	
	NSMutableDictionary* d = [NSMutableDictionary new];
	[d setObject:[NSString stringWithFormat:@"idx_*tablename_%@_%@", propertyName, (propOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc"] forKey:@"name"];
	[d setObject:propertyName forKey:@"priProperty"];
	
	if (propOrder == SRKIndexSortOrderAscending) {
		[d setObject:@"asc"forKey:@"priOrder"];
	} else if (propOrder == SRKIndexSortOrderDescending) {
		[d setObject:@"desc"forKey:@"priOrder"];
	} else if (propOrder == SRKIndexSortOrderNoCase) {
		[d setObject:@"collate nocase"forKey:@"priOrder"];
	}
	
	/* check for a duplicate */
	BOOL found = NO;
	for (NSDictionary* dict in _components) {
		NSString* name = [dict objectForKey:@"name"];
		if ([name isEqualToString:[NSString stringWithFormat:@"idx_*tablename_%@_%@", propertyName, (propOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc"]]) {
			found = YES;
		}
	}
	if (!found) {
		[_components addObject:d];
	}
	
}

- (void)addIndexForProperty:(NSString *)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder secondaryProperty:(NSString *)secProperty secondaryOrder:(enum SRKIndexSortOrder)secOrder {
	
	if (!_components) {
		_components = [NSMutableArray new];
	}
	
	NSMutableDictionary* d = [NSMutableDictionary new];
	[d setObject:[NSString stringWithFormat:@"idx_*tablename_%@_%@_%@_%@", propertyName, (propOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc", secProperty, (secOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc"] forKey:@"name"];
	[d setObject:propertyName forKey:@"priProperty"];
	
	if (propOrder == SRKIndexSortOrderAscending) {
		[d setObject:@"asc"forKey:@"priOrder"];
	} else if (propOrder == SRKIndexSortOrderDescending) {
		[d setObject:@"desc"forKey:@"priOrder"];
	} else if (propOrder == SRKIndexSortOrderNoCase) {
		[d setObject:@"collate nocase"forKey:@"priOrder"];
	}
	
	[d setObject:secProperty forKey:@"secProperty"];
	if (secOrder == SRKIndexSortOrderAscending) {
		[d setObject:@"asc" forKey:@"secOrder"];
	} else if (secOrder == SRKIndexSortOrderDescending) {
		[d setObject:@"desc" forKey:@"secOrder"];
	} else if (secOrder == SRKIndexSortOrderNoCase) {
		[d setObject:@"collate nocase"forKey:@"secOrder"];
	}
	
	/* check for a duplicate */
	BOOL found = NO;
	for (NSDictionary* dict in _components) {
		NSString* name = [dict objectForKey:@"name"];
		if ([name isEqualToString:[NSString stringWithFormat:@"idx_*tablename_%@_%@_%@_%@", propertyName, (propOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc", secProperty, (secOrder == SRKIndexSortOrderAscending) ? @"asc" : @"desc"]]) {
			found = YES;
		}
	}
	if (!found) {
		[_components addObject:d];
	}
	
}

- (void)generateIndexesForTable:(NSString*)tableName inDatabase:(NSString *)dbName{
	
	for (NSDictionary* d in _components) {
		
		if ([d objectForKey:@"secProperty"] == nil) {
			
			NSString* execSql = [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ (%@ %@);", [d objectForKey:@"name"], tableName, [d objectForKey:@"priProperty"], [d objectForKey:@"priOrder"]];
			execSql = [execSql stringByReplacingOccurrencesOfString:@"*tablename" withString:tableName];
			[SharkORM executeSQL:execSql inDatabase:dbName];
			
		} else {
			
			NSString* execSql = [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ (%@ %@, %@ %@);", [d objectForKey:@"name"], tableName, [d objectForKey:@"priProperty"], [d objectForKey:@"priOrder"], [d objectForKey:@"secProperty"], [d objectForKey:@"secOrder"]];
			execSql = [execSql stringByReplacingOccurrencesOfString:@"*tablename" withString:tableName];
			[SharkORM executeSQL:execSql inDatabase:dbName];
		}
		
	}
	
}

@end