//
//  TestObject.h
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "Department.h"

@interface Person : SRKObject

@property NSString*         Name;
@property int               age;
@property int               seq;
@property int               payrollNumber;
@property Department*       department;

@end
