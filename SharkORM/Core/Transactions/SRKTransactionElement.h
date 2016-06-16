//
//  SRKTransactionElement.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"

@interface SRKTransactionElement : NSObject

@property (strong, nonatomic) NSString*         statementSQL;
@property (strong, nonatomic) NSString*         database;
@property (strong, nonatomic) NSArray*          parameters;
@property enum SharkORMEvent                    eventType;
@property (strong, nonatomic) SRKObject*         originalObject;

@end
