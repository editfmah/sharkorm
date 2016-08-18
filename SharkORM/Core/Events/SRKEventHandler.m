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