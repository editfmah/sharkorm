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



#import "SRKLazyLoader.h"
#import "SRKObject+Private.h"

#define RELATE_ONETOONE  1
#define RELATE_ONETOMANY 2

@implementation SRKLazyLoader

@synthesize relationship, parentEntity, relatedEntity, exists;

- (id)init {
	self = [super init];
	if(self) {
		self.relatedEntity = nil;
	}
	return self;
}

- (void)reset {
	self.relatedEntity = nil;
}

- (id)fetchNode {
	
	if (self.relationship.relationshipType == RELATE_ONETOONE) {
		
		/* load this entity up based on the relationship */
		NSString* entityNameInSourceObject = self.relationship.sourceProperty;
		SRKObject* linked = (id)parentEntity;
		NSObject* primaryKey = [linked getField:entityNameInSourceObject];
		
		if (primaryKey) {
			
			SRKObject* o = [[self.relationship.targetClass alloc] initWithPrimaryKeyValue:primaryKey];
			return o.exists ? o : nil;
			
		} else {
			
			/* there is no primary key for this relationship */
			return nil;
			
		}
		
		
	} else if (self.relationship.relationshipType == RELATE_ONETOMANY) {
		
		/* fetch a set of results for this relationship as one-to-many */
		
		NSObject* primaryKey = ((SRKObject*)parentEntity).Id;
		if (primaryKey) {
			
			return [[[self.relationship.targetClass query] whereWithFormat:@"%@=%@ AND %@", self.relationship.targetProperty,primaryKey, self.relationship.restrictions] fetch];
			
		} else {
			NSArray* weakArray = [NSArray new];
			self.relatedEntity = weakArray;
			exists = NO;
		}
	}
	
	return nil;
	
}

@end
