//
//  Location.h
//  SharkORM
//
//  Created by Adrian Herridge on 15/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import <SharkORM/SharkORM.h>
#import "Department.h"

@class Department;

@interface Location : SRKObject

@property NSString* locationName;
@property Department* department;

@end
