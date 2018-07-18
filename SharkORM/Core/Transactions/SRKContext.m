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



#import "SharkORM.h"
#import "SRKEntity+Private.h"
#import "SharkORM+Private.h"
#import "SRKEntityChain.h"

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

- (void)addEntityToContext:(SRKEntity*)entity {
	[self.entities addObject:entity];
	entity.context = self;
}

- (void)removeEntityFromContext:(SRKEntity*)entity {
	[self.entities removeObject:entity];
	entity.context = nil;
}

- (BOOL)isEntityInContext:(SRKEntity*)entity {
	return [self.entities containsObject:entity];
}

- (BOOL)commit {
	
	/* commit all the objects within a transaction */
	
	__block BOOL success = YES;
    
    [SRKTransaction transaction:^{
        
        for (SRKEntity* ob in self.entities) {
            
            if (ob.isMarkedForDeletion) {
                [ob __removeRaw];
            } else {
                [ob __commitRawWithObjectChain:[SRKEntityChain new]];
            }
        }
        
    } withRollback:^{
        
        success = NO;
        
    }];
		
	return success;
	
}

@end
