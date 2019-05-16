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
	
	static NSMutableDictionary<NSString*, NSNumber*>* polled;
	if (!polled) {
		polled = [NSMutableDictionary new];
	}
	
	SyncRequestObject* r = [SyncRequestObject new];
	
	r.request[@"AppId"] = SharkSync.Settings.applicationKey;
	r.request[@"DeviceId"] = SharkSync.Settings.deviceId;
	r.request[@"AppApiAccessKey"] = SharkSync.Settings.accountKey;
	
	// now pull out the changes, as these go into the changes key.
	NSMutableArray* groups = [NSMutableArray new];
	
	r.changes = [NSMutableArray arrayWithArray:[[[[SharkSyncChange query] limit:300] order:@"timestamp"] fetch]];
	
	// check for risk of incomplete records
	if (r.changes.count == 300) {
		// risky, so remove the last record id in the results
		NSString* recordId = r.changes[299].recordId;
		while ([r.changes[r.changes.count-1].recordId isEqualToString:recordId]) {
			[r.changes removeObjectAtIndex:r.changes.count-1];
		}
	}
	
	for (SharkSyncChange* change in r.changes) {
		
		NSMutableDictionary<NSString*,id>* group = nil;
		for (NSMutableDictionary<NSString*,id>* g in groups) {
			if ([g objectForKey:@"Group"] && [((NSString*)[g objectForKey:@"Group"]) isEqualToString:change.recordGroup]) {
				group = g;
			}
		}
		if (!group) {
			group = [NSMutableDictionary new];
			[group setValue:change.recordGroup forKey:@"Group"];
			[group setValue:[NSMutableArray new] forKey:@"Changes"];
			[groups addObject:group];
		}
		
		NSMutableDictionary<NSString*,id>* entity = nil;
		for (NSMutableDictionary<NSString*,id>* e in ((NSMutableArray*)[group objectForKey:@"Changes"])) {
			if ([e objectForKey:@"Entity"] && [((NSString*)[e objectForKey:@"Entity"]) isEqualToString:change.entity]) {
				entity = e;
			}
		}
		if (!entity) {
			entity = [NSMutableDictionary new];
			[entity setValue:change.entity forKey:@"Entity"];
			[entity setValue:[NSMutableArray new] forKey:@"Records"];
			NSMutableArray* changes = [group objectForKey:@"Changes"];
			[changes addObject:entity];
		}
		
		NSMutableDictionary<NSString*,id>* record = nil;
		for (NSMutableDictionary<NSString*,id>* r in ((NSMutableArray*)[entity objectForKey:@"Records"])) {
			if ([r objectForKey:@"RecordId"] && [((NSString*)[r objectForKey:@"RecordId"]) isEqualToString:change.recordId]) {
				record = r;
			}
		}
		if (!record) {
			record = [NSMutableDictionary new];
			[record setValue:change.recordId forKey:@"RecordId"];
			[record setValue:@(change.action) forKey:@"Action"];
			[record setValue:[NSMutableDictionary new] forKey:@"Properties"];
			NSMutableArray* records = [entity objectForKey:@"Records"];
			[records addObject:record];
		}
		
		if (record) {
			NSNumber* secondsAgo = @(([NSDate date].timeIntervalSince1970 - change.timestamp) * 1000);
			[record setValue:@(secondsAgo.longLongValue) forKey:@"MillisecondsAgo"];
			if (change.value != nil && change.property != nil) {
				NSMutableDictionary<NSString*,NSString*>* properties = [record objectForKey:@"Properties"];
				[properties setValue:change.value forKey:change.property];
			}
		}
		
	}
	
	
	// now find all of the groups which need servicing based on their frequency
	NSMutableArray<SharkSyncGroup*>* selectedGroups = [NSMutableArray new];
	for (SharkSyncGroup* g in [SharkSync sharedObject].currentGroups) {
		[selectedGroups addObject:g];
	}
	
	for (SharkSyncGroup* selected in selectedGroups) {
		NSMutableDictionary<NSString*,id>* group = nil;
		for (NSMutableDictionary<NSString*,id>* g in groups) {
			if ([g objectForKey:@"Group"] && [((NSString*)[g objectForKey:@"Group"]) isEqualToString:selected.name]) {
				group = g;
			}
		}
		if (!group) {
			group = [NSMutableDictionary new];
			[group setValue:selected.name forKey:@"Group"];
			[group setValue:[NSMutableArray new] forKey:@"Changes"];
			[groups addObject:group];
		}
		if (group) {
			group[@"Tidemark"] = @(selected.tidemark);
		}
	}
	
	r.request[@"Groups"] = groups;
	
	if (groups.count == 0) {
		return nil;
	}
	
	return r;
	
}

+ (int)handleResponse:(NSDictionary *)response request:(SyncRequestObject *)request {
	
	__block BOOL changes = NO;
	__block int changeCount = 0;
	
	if (response[@"Success"] && ((NSNumber*)response[@"Success"]).boolValue == NO) {
		return changeCount;
	}
	
	// because it was successful we can remove the outbound changes
	for (SharkSyncChange* change in request.changes) {
		[change remove];
	}
	
	// now process the changes from the server, aggregated together into groups
	if (response[@"Groups"]) {
		
		[SRKTransaction transaction:^{
			
			for (NSDictionary<NSString*,id>* groupViewModel in response[@"Groups"]) {
				
				NSString* groupName = groupViewModel[@"Group"];
				NSNumber* tidemark = groupViewModel[@"Tidemark"];
				
				for (NSDictionary<NSString*,id>* changeEntityViewModel in groupViewModel[@"Changes"]) {
					
					NSString* Entity = changeEntityViewModel[@"Entity"];
					
					for (NSDictionary<NSString*,id>* changeRecordViewModel in changeEntityViewModel[@"Records"]) {
						
						changeCount++;
						
						NSString* RecordId = changeRecordViewModel[@"RecordId"];
						NSNumber* Action = changeRecordViewModel[@"Action"];
						NSDictionary<NSString*,NSString*>* properties = changeRecordViewModel[@"Properties"];
						
						changes = YES;
						
						SRKSyncObject* object = [SRKSyncObject objectFromClass:Entity withPrimaryKey:RecordId];
						
						// check for deleted record
						if (Action.intValue == 3) {
							
							if (object) {
								[object __removeRawNoSync];
							}
							
							SRKDefunctObject* defObject = [SRKDefunctObject new];
							defObject.defunctId = RecordId;
							[defObject commit];
							
						} else {
							
							if ([[[SRKDefunctObject query] where:@"defunctId = ?" parameters:@[RecordId]] count]) {
								// this object is defunct do nothing
								
							} else {
								
								if (!object && [[[SRKDefunctObject query] where:@"defunctId = ?" parameters:@[RecordId]] count] == 0) {
									object = [SRKSyncObject objectFromClass:Entity];
									[object setId:RecordId];
									[object setRecordVisibilityGroup:groupName];
								}
								
								for (NSString* Property in properties.allKeys) {
									
									
									NSString* Value = [properties objectForKey:Property];
									
									// deal with the insert/update of an object
									id decryptedValue = [SharkSync decryptValue:Value property:Property entity:Entity];
									
									// check to see if this property is actually in the call or if it exists in a different version of the model
									for (NSString* f in object.fieldNames) {
										if ([f.lowercaseString isEqualToString:Property.lowercaseString]) {
											[object setField:f value:decryptedValue];
											if ([object getRecordGroup] == nil) {
												[object setRecordVisibilityGroup:groupName];
											}
											decryptedValue = nil;
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
									
								}
								
								[object __commitRawWithObjectChainNoSync:nil];
								
							}
							
						}
						
					}
					
				}
				
				// now update the group sync tidemark
				for (SharkSyncGroup* g in [SharkSync sharedObject].currentGroups) {
					if ([g.name isEqualToString:groupName]) {
						g.tidemark = tidemark.unsignedLongLongValue;
						if (changes) {
							// jam the condition open to force an imediate call
							g.lastPolled = @(0).unsignedLongLongValue;
						} else {
							g.lastPolled = @([NSDate date].timeIntervalSince1970 * 1000).unsignedLongLongValue;
						}
						[g commit];
					}
				}
				
			}
			
			// there have been changes, so lets execute the change notification block
			if ([SharkSync sharedObject].changeBlock) {
				
				SharkSyncChanges* changes = [SharkSyncChanges new];
				
				
			}
			
			for (SharkSyncChange* change in request.changes) {
				[change remove];
			}
			
			if(request.changes.count > 0) {
				changeCount += request.changes.count;
			}
			
		} withRollback:^{
			
		}];
		
	}
	
	return changeCount;
	
}

+ (void)handleError:(NSError *)error request:(SyncRequestObject *)request {
	
}

@end
