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



#import "SRKRegistry.h"
#import "SharkORM.h"
#import "SRKObject+Private.h"
#import "SRKEventHandler+Private.h"
#import "SRKRegistryEntry.h"

@interface SRKRegistry ()

@property (strong, nonatomic) NSMutableDictionary*     tableEventRegistry;
@property (strong, nonatomic) NSMutableArray*          objectRegistry;

@end

/* private methods hidden from the public headers */
@interface SRKObject ()

@end

@implementation SRKRegistry

static SRKRegistry* this = nil;

+ (void)resetSharkORM {
    this = nil;
}

- (id)init {
	
	self = [super init];
	if (self) {
		self.objectRegistry = [NSMutableArray new];
		self.tableEventRegistry = [NSMutableDictionary new];
	}
	
	return self;
	
}

+ (SRKRegistry *)sharedInstance {
	
	if (!this) {
		this = [SRKRegistry new];
	}
	return this;
	
}

- (void)freeObjects:(NSArray*)spentObjects {
	static BOOL active = NO;
	if (!active) {
		active = YES;
		@synchronized(self.objectRegistry) {
			[self.objectRegistry removeObjectsInArray:spentObjects];
		}
		active = NO;
	}
}

- (void)broadcast:(SRKEvent *)event {
	
	/* takes an event and works out which domain/table/object registrations need to be notified */
	
	// managed object domains are dealt with first as the subsequent notifications may rely on the changes in objects already being present
	
	NSMutableArray* freedObjects = [NSMutableArray new];
	NSMutableArray* triggerableEventObjects = [NSMutableArray new];
	
	SRKObject* thisEventEntity = event.entity;
	
	if ((event.event == SharkORMEventUpdate || event.event == SharkORMEventDelete) && thisEventEntity.Id) {
		@synchronized(self.objectRegistry) {
			
			NSString* eventTable = [[thisEventEntity class] description];
			for (SRKRegistryEntry* o in self.objectRegistry) {
				
				SRKObject* thisObject = o.entity;
				
				if (thisObject) {
					
					NSNumber *thisId = thisObject.Id;
					NSNumber *eventId = thisEventEntity.Id;
					
					if (thisId) {
						if ([o.sourceTable isEqualToString:eventTable]) {
							/* if it's not the same kind of primary key, then they can't be compared anyway */
							if ([thisId isKindOfClass:eventId.class]) {
								if (([thisId isKindOfClass:[NSNumber class]] && thisId.unsignedLongLongValue == eventId.unsignedLongLongValue) || ([thisId isKindOfClass:[NSString class]] && [((NSString*)thisId) isEqualToString:(NSString*)eventId])) {
									
									SRKObject* obj = o.entity;
									
									/* check for a domain match */
									if (o.entity.managedObjectDomain && thisEventEntity.managedObjectDomain && [o.entity.managedObjectDomain isEqualToString:thisEventEntity.managedObjectDomain]) {
										
										[obj notifyObjectChanges:event];
        
									}
									
									if (obj.registeredEventBlocks.count > 0) {
										[triggerableEventObjects addObject:obj];
									}
									
								}
							}
						}
					}
				} else {
					[freedObjects addObject:o];
				}
			}
		}
	}
	
	/* trigger any events that we have put by, block may modify the event objects so we can't do it with a lock around the array */
	for (SRKObject* obj in triggerableEventObjects) {
		[obj triggerInternalEvent:event];
	}
	
	// table events
	@synchronized(self.tableEventRegistry) {
		for (SRKRegistryEntry* o in [self.tableEventRegistry objectForKey:[thisEventEntity.class description]]) {
			SRKEventHandler* h = o.tableEventHandler;
			[h triggerInternalEvent:event];
		}
	}
	
	if (freedObjects.count > 0) {
		[self performSelectorInBackground:@selector(freeObjects:) withObject:freedObjects];
	}
	
}

- (void)registerObject:(SRKObject *)object {
	
	/* test to see if the object is ready yet, e.g. existing */
	if (!object.Id) {
		/* an object without an ID cannot be placed into the registry, as it can have no twins */
		return;
	}
	
	/* create the storage object, needed to maintain a weak reference to the SRKObject */
	
	SRKRegistryEntry* o = [SRKRegistryEntry new];
	o.entity = object;
	o.sourceTable = [[object class] description];
	o.tableEventHandler = nil;
	
	@synchronized(self.objectRegistry) {
		[self.objectRegistry addObject:o];
	}
	
}

- (void)add:(NSArray *)objects intoDomain:(NSString*)domain {
	
	/* optimised to spped up inserts of larger results sets when using the fluent marker */
	
	@synchronized(self.objectRegistry) {
		
		for (SRKObject* object in objects) {
			/* test to see if the object is ready yet, e.g. existing */
			if (object.Id) {
				
				/* an object without an ID cannot be placed into the registry, as it can have no twins */
				/* create the storage object, needed to maintain a weak reference to the SRKObject */
				
				SRKRegistryEntry* o = [SRKRegistryEntry new];
				o.entity = object;
				o.sourceTable = [[object class] description];
				o.tableEventHandler = nil;
				[object rawSetManagedObjectDomain:domain];
				
				[self.objectRegistry addObject:o];
				
			}
		}
		
	}
	
}

- (void)registerHandler:(SRKEventHandler *)handler {
	
	/* create the storage object, needed to maintain a weak reference to the SRKEventHandler */
	if (!handler) {
		return;
	}
	
	SRKRegistryEntry* o = [SRKRegistryEntry new];
	o.entity = nil;
	o.sourceTable = [[handler classDecl] description];
	o.tableEventHandler = handler;
	
	@synchronized(self.tableEventRegistry) {
		
		if (![self.tableEventRegistry objectForKey:o.sourceTable]) {
			[self.tableEventRegistry setObject:[NSMutableArray new] forKey:o.sourceTable];
		}
		
		NSMutableArray* tArray = [self.tableEventRegistry objectForKey:o.sourceTable];
		[tArray addObject:o];
	}
	
}

- (void)remove:(SRKObject *)object {
	
	/* create the storage object, needed to maintain a weak reference to the SRKObject */
	
	SRKRegistryEntry* o = [SRKRegistryEntry new];
	o.sourceTable = [[object class] description];
	o.tableEventHandler = nil;
	
	NSMutableArray* freedObjects = [NSMutableArray new];
	
	@synchronized(self.objectRegistry) {
		
		for (SRKRegistryEntry* o in self.objectRegistry) {
			
			SRKObject* obj = o.entity;
			if (!obj || obj == object) {
				[freedObjects addObject:o];
			}
			
		}
		
	}
	
	if (freedObjects.count > 0) {
		[self performSelectorInBackground:@selector(freeObjects:) withObject:freedObjects];
	}
	
}

- (void)deregisterHandler:(SRKEventHandler *)handler {
	
	/* create the storage object, needed to maintain a weak reference to the SRKEventHandler */
	if (!handler) {
		return;
	}
	
	SRKRegistryEntry* o = [SRKRegistryEntry new];
	o.entity = nil;
	o.sourceTable = [[handler classDecl] description];
	o.tableEventHandler = nil;
	
	@synchronized(self.tableEventRegistry) {
		
		if (![self.tableEventRegistry objectForKey:o.sourceTable]) {
			[self.tableEventRegistry setObject:[NSMutableArray new] forKey:o.sourceTable];
		}
		
		NSMutableArray* tArray = [self.tableEventRegistry objectForKey:o.sourceTable];
		NSMutableArray* toBeRemoved = [NSMutableArray new];
		for (SRKRegistryEntry* ob in tArray) {
			if (ob.tableEventHandler == handler || ob.tableEventHandler == nil) {
				[toBeRemoved addObject:ob];
			}
		}
		[tArray removeObjectsInArray:toBeRemoved];
	}
	
}

@end
