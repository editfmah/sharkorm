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

#import "SyncRequest.h"
#import "SharkSync+Private.h"

@implementation SyncRequestObject

- (instancetype)init {
    self = [super init];
    if (self) {
        self.request = [NSMutableDictionary new];
    }
    return self;
}

@end


@implementation SyncRequest

+ (SyncRequestObject *)generateSyncRequest {
    
    SyncRequestObject* r = [SyncRequestObject new];
    
    r.request[@"AppId"] = SharkSync.Settings.applicationKey;
    r.request[@"DeviceId"] = SharkSync.Settings.deviceId;
    r.request[@"AppApiAccessKey"] = SharkSync.Settings.accountKey;
    
    // now pull out the changes, as these go into the changes key.
    NSMutableArray* changes = [NSMutableArray new];
    
    r.changes = [[[[SharkSyncChange query] limit:500] order:@"timestamp"] fetch];
    for (SharkSyncChange* change in r.changes) {
        
        NSMutableDictionary* c = [NSMutableDictionary new];
        NSNumber* secondsAgo = @(([NSDate date].timeIntervalSince1970 - change.timestamp) * 1000);
        
        if (change.recordGroup) {
            c[@"Group"] = [SharkSync MD5FromString:change.recordGroup];
            r.hashes[[SharkSync MD5FromString:change.recordGroup]] = change.recordGroup;
        }
        if (change.entity) { c[@"Entity"] = change.entity; }
        if (change.recordId) { c[@"RecordId"] = change.recordId; }
        if (change.property) { c[@"Property"] = change.property; }
        if (change.timestamp) { c[@"MillisecondsAgo"] = @(secondsAgo.unsignedLongLongValue); }
        if (change.value) { c[@"Value"] = change.value; }
        
        [changes addObject:c];
        
    }
    
    r.request[@"Changes"] = changes;
    
    
    // now find all of the groups which need servicing based on their frequency
    NSMutableArray* groups = [NSMutableArray new];
    
    NSMutableArray<SharkSyncGroup*>* selectedGroups = [NSMutableArray new];
    uint64_t time = @([NSDate date].timeIntervalSince1970 * 1000).unsignedLongLongValue;
    for (SharkSyncGroup* g in [SharkSync sharedObject].currentGroups) {
        if ((g.lastPolled + g.frequency) < time) {
            [selectedGroups addObject:g];
        }
    }
    
    for (SharkSyncGroup* group in selectedGroups) {
        NSMutableDictionary* g = [NSMutableDictionary new];
        if (group.name) {
            g[@"Group"] = [SharkSync MD5FromString:group.name];
            r.hashes[[SharkSync MD5FromString:group.name]] = group.name;
        }
        g[@"Tidemark"] = @(group.tidemark);
        [groups addObject:g];
    }
    
    r.request[@"Groups"] = groups;
    
    return r;
    
}

+ (void)handleResponse:(NSDictionary *)response request:(SyncRequestObject *)request {
    
    if (response[@"Success"] && ((NSNumber*)response[@"Success"]).boolValue == NO) {
        return;
    }
    
    // because it was successful we can remove the outbound changes
    for (SharkSyncChange* change in request.changes) {
        [change remove];
    }
    
    @synchronized([SharkSync sharedObject].currentGroups) {
        [SharkSync sharedObject].countOfChangesToSyncUp -= request.changes.count;
    }
    
    // now process the changes from the server, aggregated together into groups
    if (response[@"Groups"]) {
        for (NSDictionary<NSString*,id>* group in response[@"Groups"]) {
            
            NSString* groupName = request.hashes[group[@"Group"]];
            NSNumber* tidemark = group[@"Tidemark"];
            
            for (NSDictionary<NSString*,id>* change in group[@"Changes"]) {
                
                NSString* RecordId = change[@"RecordId"];
                NSString* Entity = change[@"Entity"];
                NSString* Property = change[@"Property"];
                NSString* Value = change[@"Value"];
                
                if (RecordId && Entity && Property) {
                    
                    // check for deleted record
                    if ([Property containsString:@"__delete__"]) {
                        
                        SRKSyncObject* deadObject = [SRKSyncObject objectFromClass:Entity withPrimaryKey:RecordId];
                        if (deadObject) {
                            [deadObject __removeRawNoSync];
                        }
                        
                        SRKDefunctObject* defObject = [SRKDefunctObject new];
                        defObject.defunctId = RecordId;
                        [defObject commit];
                        
                    } else {
                        
                        // deal with the insert/update of an object
                        id decryptedValue = [SharkSync decryptValue:Value];
                        SRKSyncObject* targetObject = [SRKSyncObject objectFromClass:Entity withPrimaryKey:RecordId];
                        if (targetObject != nil) {
                            
                            // check to see if this property is actually in the call or if it exists in a different version of the model
                            for (NSString* f in targetObject.fieldNames) {
                                if ([f isEqualToString:Property]) {
                                    [targetObject setField:Property value:decryptedValue];
                                    if ([targetObject getRecordGroup] == nil) {
                                        [targetObject setRecordVisibilityGroup:groupName];
                                    }
                                    if ([targetObject __commitRawWithObjectChainNoSync:nil] != NO) {
                                        decryptedValue = nil;
                                    }
                                }
                            }
                            
                            if (decryptedValue != nil) {
                                
                                // cache this property value for a future version of the model
                                SRKDeferredChange* futureChange = [SRKDeferredChange new];
                                futureChange.key = RecordId;
                                futureChange.className = Entity;
                                futureChange.value = Value;
                                futureChange.property = Property;
                                [futureChange commit];
                                
                            }
                            
                        } else {
                            
                            // object does not exist, so either a new record or an object not present in the model
                            // first check for defunct object
                            if (![[[SRKDefunctObject query] where:@"defunctId = ?" parameters:@[RecordId]] count]) {
                                // record has not been deleted
                                SRKSyncObject* newObject = [SRKSyncObject objectFromClass:Entity];
                                if (newObject) {
                                    
                                    newObject.Id = RecordId;
                                    [newObject setRecordVisibilityGroup:groupName];
                                    
                                    for (NSString* f in newObject.fieldNames) {
                                        if ([f isEqualToString:Property]) {
                                            [newObject setField:Property value:decryptedValue];
                                            if ([newObject getRecordGroup] == nil) {
                                                [newObject setRecordVisibilityGroup:groupName];
                                            }
                                            if ([newObject __commitRawWithObjectChainNoSync:nil] != NO) {
                                                decryptedValue = nil;
                                            }
                                        }
                                    }
                                    
                                    if (decryptedValue != nil) {
                                        
                                        // cache this property value for a future version of the model
                                        SRKDeferredChange* futureChange = [SRKDeferredChange new];
                                        futureChange.key = RecordId;
                                        futureChange.className = Entity;
                                        futureChange.value = Value;
                                        futureChange.property = Property;
                                        [futureChange commit];
                                        
                                    }
                                    
                                } else {
                                    
                                    // cache this property value for a future version of the model
                                    SRKDeferredChange* futureChange = [SRKDeferredChange new];
                                    futureChange.key = RecordId;
                                    futureChange.className = Entity;
                                    futureChange.value = Value;
                                    futureChange.property = Property;
                                    [futureChange commit];
                                    
                                }
                                
                            }
                        }
                    }
                }
            }
            
            // now update the group sync tidemark
            for (SharkSyncGroup* g in [SharkSync sharedObject].currentGroups) {
                if ([g.name isEqualToString:groupName]) {
                    g.tidemark = tidemark.unsignedLongLongValue;
                    g.lastPolled = @([NSDate date].timeIntervalSince1970 * 1000).unsignedLongLongValue;
                    [g commit];
                }
            }
            
        }
    }
    
}

+ (void)handleError:(NSError *)error request:(SyncRequestObject *)request {
    
}

@end
