//
//  SRKJoinObject.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKJoinObject.h"

@implementation SRKJoinObject

- (instancetype)setJoinOn:(Class)joinOn joinWhere:(NSString *)joinWhere joinLeft:(NSString *)joinLeft joinRight:(NSString *)joinRight {
	
	self.joinOn = joinOn;
	self.joinWhere = joinWhere;
	self.joinLeft = joinLeft;
	self.joinRight = joinRight;
	
	return self;
}

@end
