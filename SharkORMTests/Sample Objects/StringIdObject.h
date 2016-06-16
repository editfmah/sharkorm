//
//  StringIdObject.h
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "StringIdRelatedObject.h"

@interface StringIdObject : SRKObject

@property (strong, nonatomic) NSString* Id;
@property (strong) NSString* value;
@property (strong) StringIdRelatedObject* related;

@end
