//
//  TestObject.m
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "Person.h"

@implementation Person

@dynamic Name,age,department,payrollNumber,seq,location;

+ (NSArray *)FTSParametersForEntity {
	return @[@"Name"];
}

+ (NSDictionary *)defaultValuesForEntity {
	return @{@"age": @(36)};
}

@end

@implementation SmallPerson

@dynamic height;

@end
