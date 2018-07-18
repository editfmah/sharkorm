//
//  SharkSyncGroup.m
//  SharkORM
//
//  Created by Adrian Herridge on 15/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import "SharkSyncGroup.h"

@implementation SharkSyncGroup

@dynamic lastPolled, tidemark, name, frequency, outstandingData;

+ (instancetype)groupWithName:(NSString*)name {
    return [[[[SharkSyncGroup query] where:@"name = ?" parameters:@[name]] fetch] firstObject];
}

@end
