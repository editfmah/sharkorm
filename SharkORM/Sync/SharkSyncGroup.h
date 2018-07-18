//
//  SharkSyncGroup.h
//  SharkORM
//
//  Created by Adrian Herridge on 15/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import <SharkORM/SharkORM.h>

@interface SharkSyncGroup : SRKObject

@property (strong) NSString* name;
@property unsigned long long tidemark;
@property unsigned long long lastPolled;
@property unsigned long long frequency;
@property BOOL outstandingData;

+ (instancetype)groupWithName:(NSString*)name;

@end
