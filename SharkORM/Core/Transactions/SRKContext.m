//
//  SRKContext.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "SRKObject+Private.h"
#import "SharkORM+Private.h"
#import "SRKObjectChain.h"

@interface SRKContext ()

@property (nonatomic, strong)   NSMutableArray* entities;

@end

@implementation SRKContext

- (id)init {
	self = [super init];
	if (self) {
		self.entities = [NSMutableArray new];
	}
	return self;
}

- (void)addEntityToContext:(SRKObject*)entity {
	[self.entities addObject:entity];
	entity.context = self;
}

- (void)removeEntityFromContext:(SRKObject*)entity {
	[self.entities removeObject:entity];
	entity.context = nil;
}

- (BOOL)isEntityInContext:(SRKObject*)entity {
	return [self.entities containsObject:entity];
}

- (BOOL)commit {
	
	/* wrap all of the statements up in a single transaction */
	
	__block BOOL success = YES;
	
	NSMutableArray* databases = [NSMutableArray new];
	for (SRKObject* o in self.entities) {
		BOOL found = NO;
		for (NSString* s in databases) {
			if([s isEqualToString:[SharkORM databaseNameForClass:o.class]]) {
				found = YES;
			}
		}
		if (!found) {
			[databases addObject:[SharkORM databaseNameForClass:o.class]];
		}
	}
	
	for (NSString* dbName in databases) {
		[SharkORM executeSQL:@"BEGIN" inDatabase:dbName];
	}
	
	for (SRKObject* ob in self.entities) {
		
		if (ob.isMarkedForDeletion) {
			[ob __removeRaw];
		} else {
			[ob __commitRawWithObjectChain:[SRKObjectChain new]];
		}
	}
	
	for (NSString* dbName in databases) {
		[SharkORM executeSQL:@"END" inDatabase:dbName];
	}
	
	return success;
	
}

@end