//
//  SRKQueryAsyncHandler.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SRKQuery+Private.h"
#import "SharkORM+Private.h"
#import "SRKResultSet+Private.h"
#import "SRKQueryAsyncHandler+Private.h"

@implementation SRKQueryAsyncHandler

- (id)initWithQuery:(SRKQuery *)query andAsyncBlock:(SRKQueryAsyncResponse)block {
	self = [super init];
	if (self) {
		self.query = query;
		self.block = block;
		[self performSelectorInBackground:@selector(execute) withObject:nil];
	}
	return self;
}

- (void)cancelQuery {
	self.query.quit = YES;
}

- (void)executeBlock:(SRKResultSet*)results {
	if (self.block) {
		self.block(results);
	}
}

- (void)execute {
	
	if (self.query.batchSize) {
		
		SRKResultSet* results = [[SRKResultSet alloc] initWithArrayOfPrimaryKeys:[[SharkORM new] fetchIDsForQuery:self.query] andQuery:self.query];
		if (self.onMainThread) {
			[self performSelectorOnMainThread:@selector(executeBlock:) withObject:results waitUntilDone:NO];
		} else {
			[self executeBlock:results];
		}
		
	} else {
		
		SRKResultSet* results = [[SRKResultSet alloc] initWithArray:[[SharkORM new] fetchEntitySetForQuery:self.query]];
		if (self.onMainThread) {
			[self performSelectorOnMainThread:@selector(executeBlock:) withObject:results waitUntilDone:NO];
		} else {
			[self executeBlock:results];
		}
		
	}
	
}

@end