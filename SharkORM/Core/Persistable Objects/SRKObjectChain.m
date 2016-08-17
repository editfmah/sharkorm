//    MIT License
//
//    Copyright (c) 2016 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.



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
