//
//  SharkSyncChange.h
//  SharkORM
//
//  Created by Adrian Herridge on 15/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import <SharkORM/SharkORM.h>

@interface SharkSyncChange : SRKObject

@property (strong) NSString* recordId;
@property (strong) NSString* property;
@property (strong) NSString* entity;
@property double timestamp;
@property (strong) NSString* value;
@property int action;
@property (strong) NSString* recordGroup;
@property (strong) NSString* sync_op;

@end
