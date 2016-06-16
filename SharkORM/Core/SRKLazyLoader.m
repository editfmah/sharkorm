//
//  SRKLazyLoader.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKLazyLoader.h"
#import "SRKObject+Private.h"

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
	
	if (self.relationship.relationshipType == SRK_RELATE_ONETOONE) {
		
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
		
		
	} else if (self.relationship.relationshipType == SRK_RELATE_ONETOMANY) {
		
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
