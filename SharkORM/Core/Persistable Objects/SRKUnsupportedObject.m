//
//  SRKUnsupportedObject.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKUnsupportedObject.h"

@implementation SRKUnsupportedObject

-(void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.object forKey:@"object"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super init])) {
		self.object = [aDecoder decodeObjectForKey:@"object"];
	}
	return self;
}

@end
