//
//  SRKSQLiteHandle.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKSQLiteHandle.h"

@implementation SRKSQLiteHandle

- (instancetype)initWithHandle:(sqlite3 *)handle {
	self = [super init];
	if (self) {
		self.databaseHandle = handle;
	}
	return self;
}

@end
