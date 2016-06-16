//
//  SRKRegistryEntry.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SRKObject;
@class SRKEventHandler;

@interface SRKRegistryEntry : NSObject

@property (weak, nonatomic)    SRKObject*       entity;
@property (strong, nonatomic)  NSString*       sourceTable;
@property (weak, nonatomic)    SRKEventHandler* tableEventHandler;

@end
