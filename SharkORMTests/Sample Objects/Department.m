//
//  Department.m
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "Department.h"

@implementation Department

@dynamic name, location;

+ (SRKIndexDefinition *)indexDefinitionForEntity {
    
    return [[SRKIndexDefinition alloc] init:@[@"name",@"age"]];

}

@end
