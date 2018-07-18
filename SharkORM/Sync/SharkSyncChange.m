//
//  SharkSyncChange.m
//  SharkORM
//
//  Created by Adrian Herridge on 15/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import "SharkSyncChange.h"
#import "SharkSync+Private.h"

@implementation SharkSyncChange

@dynamic action,entity,property,recordGroup,recordId,sync_op,value,timestamp;

- (void)entityDidInsert {
    [SharkSync addChangesWritten:1];
}

@end
