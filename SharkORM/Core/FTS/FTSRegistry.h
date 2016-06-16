//
//  FTSRegistry.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"

@interface FTSRegistry : SRKObject

@property NSString* tableName;
@property NSString* columns;
@property BOOL uptodate;

+ (FTSRegistry*)registryForTable:(NSString*)tableName;
+ (BOOL)readyForAction:(NSString*)tableName;

@end
