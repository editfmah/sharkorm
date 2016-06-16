//
//  SRKEventBlockHolder.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"

@interface SRKEventBlockHolder : NSObject

@property (nonatomic, copy) SRKEventRegistrationBlock    block;
@property int                                           events;
@property BOOL                                          useMainThread;
@property BOOL                                          updateSelf;
@property (strong) SRKEvent*                             tempEvent;

@end
