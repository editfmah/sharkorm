//
//  SRKEventHandler.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "SRKRegistry.h"
#import "SRKEventHandler+Private.h"
#import "SRKEventBlockHolder.h"

@implementation SRKEventHandler

- (Class)classDecl {
	return classDecl;
}

- (SRKEventHandler*)entityclass:(Class)entityClass {
	
	classDecl = entityClass;
	[[SRKRegistry sharedInstance] registerHandler:self];
	return self;
	
}

- (id)init {
	self = [super init];
	if (self) {
		
		classDecl = nil;
		registeredEventBlocks = [NSMutableArray new];
		
	}
	return self;
}

- (void)executeEventBlock:(SRKEventBlockHolder*)block {
	block.block(block.tempEvent);
	block.tempEvent = nil;
}

- (void)triggerInternalEvent:(SRKEvent*)e {
	
	if (self.delegate && [self.delegate conformsToProtocol:@protocol(SRKEventDelegate)]) {
		[self.delegate SRKObjectDidRaiseEvent:e];
	}
	
	/* now check for registered blocks for this object */
	for (SRKEventBlockHolder* bh in registeredEventBlocks) {
		if (bh.events & e.event) {
			/* this bit is set */
			bh.tempEvent = e;
			if (bh.useMainThread) {
				[self performSelectorOnMainThread:@selector(executeEventBlock:) withObject:bh waitUntilDone:YES];
			} else {
				[self performSelectorInBackground:@selector(executeEventBlock:) withObject:bh];
			}
		}
	}
	
}

- (void)registerBlockForEvents:(enum SharkORMEvent)events withBlock:(SRKEventRegistrationBlock)block onMainThread:(BOOL)mainThread {
	
	SRKEventBlockHolder* bh = [SRKEventBlockHolder new];
	bh.events = events;
	bh.block = block;
	bh.useMainThread = mainThread;
	
	[registeredEventBlocks addObject:bh];

}

- (void)clearAllRegisteredBlocks {
	registeredEventBlocks = [NSMutableArray new];
}

- (void)dealloc {
	[[SRKRegistry sharedInstance] deregisterHandler:self];
	registeredEventBlocks = nil;
	self.delegate = nil;
}

@end