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
#import "SRKObject+Private.h"
#import "SharkORM+Private.h"
#import "SRKObjectChain.h"

@interface SRKContext ()

@property (nonatomic, strong)   NSMutableArray* entities;

@end

@implementation SRKContext

- (id)init {
	self = [super init];
	if (self) {
		self.entities = [NSMutableArray new];
	}
	return self;
}

- (void)addEntityToContext:(SRKObject*)entity {
	[self.entities addObject:entity];
	entity.context = self;
}

- (void)removeEntityFromContext:(SRKObject*)entity {
	[self.entities removeObject:entity];
	entity.context = nil;
}

- (BOOL)isEntityInContext:(SRKObject*)entity {
	return [self.entities containsObject:entity];
}

- (BOOL)commit {
	
	/* wrap all of the statements up in a single transaction */
	
	__block BOOL success = YES;
	
	NSMutableArray* databases = [NSMutableArray new];
	for (SRKObject* o in self.entities) {
		BOOL found = NO;
		for (NSString* s in databases) {
			if([s isEqualToString:[SharkORM databaseNameForClass:o.class]]) {
				found = YES;
			}
		}
		if (!found) {
			[databases addObject:[SharkORM databaseNameForClass:o.class]];
		}
	}
	
	for (NSString* dbName in databases) {
		[SharkORM executeSQL:@"BEGIN" inDatabase:dbName];
	}
	
	for (SRKObject* ob in self.entities) {
		
		if (ob.isMarkedForDeletion) {
			[ob __removeRaw];
		} else {
			[ob __commitRawWithObjectChain:[SRKObjectChain new]];
		}
	}
	
	for (NSString* dbName in databases) {
		[SharkORM executeSQL:@"END" inDatabase:dbName];
	}
	
	return success;
	
}

@end