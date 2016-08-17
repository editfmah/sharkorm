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