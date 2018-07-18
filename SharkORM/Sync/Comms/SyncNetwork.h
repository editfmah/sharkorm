//
//  SyncNetwork.h
//  SharkORM
//
//  Created by Adrian Herridge on 16/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyncNetwork : NSObject

+ (instancetype)sharedInstance;
- (void)startService;
- (void)stopService;

@end
