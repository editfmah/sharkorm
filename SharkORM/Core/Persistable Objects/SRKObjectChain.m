//
//  SRKObjectChain.m
//  SharkORM
//
//  Created by Adrian Herridge on 30/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "SRKObjectChain.h"

@interface SRKObjectChain ()

@property NSMutableArray* objects;
@property NSMutableArray* postCommitalObjectsToUpdate;
@property NSMutableArray* postCommitalPropertiesToSet;
@property NSMutableArray* postCommitalObjectsToBeSetIntoProperties;

@end

@implementation SRKObjectChain

- (instancetype)init {
    self = [super init];
    if (self) {
        self.objects = [NSMutableArray new];
        self.postCommitalObjectsToUpdate = [NSMutableArray new];
        self.postCommitalPropertiesToSet = [NSMutableArray new];
        self.postCommitalObjectsToBeSetIntoProperties = [NSMutableArray new];
    }
    return self;
}

- (instancetype)addObjectToChain:(SRKObject*)o {
    if (![self doesObjectExistInChain:o]) {
        [self.objects addObject:o];
    }
    return self;
}

- (BOOL)doesObjectExistInChain:(SRKObject*)o {
    return [self.objects containsObject:o];
}

- (BOOL)isOriginatingObject:(SRKObject*)o {
    if (self.objects.count && [self.objects objectAtIndex:0] == o) {
        return YES;
    }
    return NO;
}

- (BOOL)hasUnresolvedPersistence {
    if (self.postCommitalObjectsToUpdate.count) {
        return YES;
    }
    return NO;
}

- (void)setPostCommitalUpdate:(SRKObject*)obj property:(NSString*)property targetProperty:(SRKObject*)target {
    [self.postCommitalObjectsToUpdate addObject:obj];
    [self.postCommitalPropertiesToSet addObject:property];
    [self.postCommitalObjectsToBeSetIntoProperties addObject:target];
}

@end
