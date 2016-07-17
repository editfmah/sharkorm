//
//  SRKObjectChain.h
//  SharkORM
//
//  Created by Adrian Herridge on 30/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"

@interface SRKObjectChain : NSObject

- (instancetype)addObjectToChain:(SRKObject*)o;
- (BOOL)doesObjectExistInChain:(SRKObject*)o;
- (BOOL)isOriginatingObject:(SRKObject*)o;
- (BOOL)hasUnresolvedPersistence;
- (void)setPostCommitalUpdate:(SRKObject*)obj property:(NSString*)property targetProperty:(SRKObject*)target;

@end
