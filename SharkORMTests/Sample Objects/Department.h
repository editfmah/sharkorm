//
//  Department.h
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "Location.h"

@class Location;

@interface Department : SRKObject

@property NSString* name;
@property Location* location;

@end
