//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
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


#import "SRKSyncOptions.h"
#import "SharkORM+Private.h"
#import "SharkSync+Private.h"
#import "SRKEntity+Private.h"
#import "SRKEntityChain.h"
#import "SRKSyncRegisteredClass.h"

@interface SRKSyncObject ()

@property NSString* recordVisibilityGroup;

@end

@implementation SRKSyncObject

@dynamic recordVisibilityGroup;

+ (void)initialize {
    
    [super initialize];
    
}

- (BOOL)commit {
    
    /* because this is going to happen, we need to generate a primary key now */
    if (!self.Id) {
        [self setId:[[[NSUUID UUID] UUIDString] lowercaseString]];
    }
    
    return [self commitInGroup:SHARKSYNC_DEFAULT_GROUP]; // set the global group
    
}

- (BOOL)commitInGroup:(NSString*)group {
    
    // hash this group
    [SharkSync setEffectiveRecorGroup:group];
    
    if([super commit]) {
        
        [SharkSync clearEffectiveRecordGroup];
        return YES;
        
    }
    [SharkSync clearEffectiveRecordGroup];
    return NO;
    
}

- (BOOL)remove {
    
    if (!self.recordVisibilityGroup) {
        [SharkSync setEffectiveRecorGroup:SHARKSYNC_DEFAULT_GROUP];
    } else {
        [SharkSync setEffectiveRecorGroup:self.recordVisibilityGroup];
    }
    
    if ([super remove]) {
        [SharkSync clearEffectiveRecordGroup];
        return YES;
    }
    [SharkSync clearEffectiveRecordGroup];
    return NO;
    
}

- (BOOL)__commitRawWithObjectChain:(SRKEntityChain *)chain {
    
    // hash this group
    NSString* group = [SharkSync getEffectiveRecordGroup];
    
    // pull out all the change sthat have been made, by the dirtyField flags
    NSMutableDictionary* changes = [NSMutableDictionary new];
    NSMutableDictionary* combinedChanges = self.entityContentsAsObjects;
    for (NSString* dirtyField in [self dirtyFields]) {
        [changes setObject:[combinedChanges objectForKey:dirtyField] forKey:dirtyField];
    }
        
    if (self.recordVisibilityGroup && ![self.recordVisibilityGroup isEqualToString:group]) {
        
        // group has changed, queue a delete for the old record before the commit goes through for the new
        [SharkSync queueObject:self withChanges:nil withOperation:SharkSyncOperationDelete inHashedGroup:self.recordVisibilityGroup];
        
        // generate the new UUID
        NSString* newUUID = [[[NSUUID UUID] UUIDString] lowercaseString];
        
        // create a new uuid for this record, as it has to appear to the server to be new
        [[SharkORM new] replaceUUIDPrimaryKey:self withNewUUIDKey:newUUID];
        
        // if there are any embedded objects, then they will have their record group potentially changed too & and a new UUID
        
        NSMutableArray* updatedEmbeddedObjects = [NSMutableArray new];
        
        for (SRKSyncObject* o in self.embeddedEntities.allValues) {
            if ([o isKindOfClass:[SRKSyncObject class]]) {
                // check to see if this object has already appeard in this chain.
                if (![chain doesObjectExistInChain:o]) {
                    // now check to see if this is a different record group, if so replace it and regen the UDID
                    if (o.recordVisibilityGroup && ![o.recordVisibilityGroup isEqualToString:group]) {
                        // group has changed, queue a delete for the old record before the commit goes through for the new
                        [SharkSync queueObject:o withChanges:nil withOperation:SharkSyncOperationDelete inHashedGroup:o.recordVisibilityGroup];
                        // generate the new UUID
                        NSString* newUUID = [[[NSUUID UUID] UUIDString] lowercaseString];
                        // create a new uuid for this record, as it has to appear to the server to be new
                        [[SharkORM new] replaceUUIDPrimaryKey:o withNewUUIDKey:newUUID];
                        o.recordVisibilityGroup = group;
                        
                        // now we have to flag all fields as dirty, because they need to have their values written to the upstream table
                        for (NSString* field in o.fieldNames) {
                            [o.dirtyFields setObject:@(1) forKey:field];
                        }
                        
                        // add object to the list of changes
                        [updatedEmbeddedObjects addObject:o];
                        [o __commitRawWithObjectChain:chain];
                    }
                }
            }
        }
        
        for (SRKRelationship* r in [SharkSchemaManager.shared relationshipsForEntity:[self.class description] type:1]) {
            
            /* this is a link field that needs to be updated */
            
            SRKSyncObject* e = [self.embeddedEntities objectForKey:r.entityPropertyName];
            if(e && [e isKindOfClass:[SRKSyncObject class]]) {
                if ([updatedEmbeddedObjects containsObject:e]) {
                    [self setField:[NSString stringWithFormat:@"%@",r.entityPropertyName] value:((SRKSyncObject*)e).Id];
                }
            }
            
        }
        
        // now ensure that all values are written for this new record
        NSMutableDictionary* entityValues = [NSMutableDictionary new];
        for (NSString* field in self.fieldNames) {
            id value = [self getField:field];
            [entityValues setObject:value ? value : [NSNull null] forKey:field];
        }
        
        changes = self.entityContentsAsObjects;
        
    }
    
    self.recordVisibilityGroup = group;
    BOOL exists = self.exists;
    if([super __commitRawWithObjectChain:chain]) {
        
        [SharkSync queueObject:self withChanges:changes withOperation:exists ? SharkSyncOperationSet : SharkSyncOperationCreate inHashedGroup:group];
        return YES;
        
    }
    
    return NO;
    
}

- (BOOL)__removeRaw {
    
    id cachedPK = [self Id];
    if ([super __removeRaw]) {
        [self setId:cachedPK];
        [SharkSync queueObject:self withChanges:nil withOperation:SharkSyncOperationDelete inHashedGroup:[SharkSync getEffectiveRecordGroup]];
        [self setId:nil];
        return YES;
    }
    
    return NO;
    
}

- (BOOL)__commitRawWithObjectChainNoSync:(SRKEntityChain *)chain {
    
    return [super __commitRawWithObjectChain:[SRKEntityChain new]];
    
}

+(SRKSyncObject*)objectFromClass:(NSString*)cls withPrimaryKey:(NSString*)pk {
    if (!NSClassFromString(cls)) {
        if (!NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:cls])) {
            return nil;
        }
    }
    Class cl = [[NSClassFromString(cls) new] objectWithPrimaryKeyValue:pk];
    if (!cl) {
        cl = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:cls]);
    }
    return [cl objectWithPrimaryKeyValue:pk];
}

+ (SRKSyncObject *)objectFromClass:(NSString *)cls {
    Class srkClass = NSClassFromString(cls);
    if (!srkClass) {
        srkClass = NSClassFromString([[SRKGlobals sharedObject] getFQNameForClass:cls]);
    }
    return [srkClass new];
}

- (void)setRecordVisibilityGroup:(NSString *)group {
    self.recordVisibilityGroup = group;
}

- (NSString*)getRecordGroup {
    return self.recordVisibilityGroup;
}

- (BOOL)__removeRawNoSync {
    return [super __removeRaw];
}

@end
