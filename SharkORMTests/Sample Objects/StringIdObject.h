//
//  StringIdObject.h
//  SharkORMFramework
//
//  Copyright (c) 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"
#import "StringIdRelatedObject.h"

@interface StringIdObject : SRKStringObject

@property (strong) NSString* value;
@property (strong) StringIdRelatedObject* related;

@end
