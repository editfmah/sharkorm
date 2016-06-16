//
//  SRKRegistry.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SRKEvent;
@class SRKEventHandler;
@class SRKObject;

@interface SRKRegistry : NSObject

+ (SRKRegistry*)sharedInstance;
- (void)broadcast:(SRKEvent*)event;
- (void)registerHandler:(SRKEventHandler*)handler;
- (void)deregisterHandler:(SRKEventHandler*)handler;
- (void)registerObject:(SRKObject*)object;
- (void)add:(NSArray*)objects intoDomain:(NSString*)domain;
- (void)remove:(SRKObject*)object;
+ (void)resetSharkORM;

@end
