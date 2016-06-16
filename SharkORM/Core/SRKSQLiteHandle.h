//
//  SRKSQLiteHandle.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"

@interface SRKSQLiteHandle : NSObject

@property sqlite3* databaseHandle;

- (instancetype)initWithHandle:(sqlite3*)handle;

@end
