//
//  SRKTransactionGroup.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SRKTransactionElement.h"

@interface SRKTransactionGroup : NSObject

@property (strong, nonatomic) NSMutableArray*   transactionItems;
@property (strong, nonatomic) NSMutableArray*   usedDatabases;
@property (strong) NSString*					startTransactionStatement;
@property (strong) NSString*					commitTransactionStatement;
@property (strong) NSString*					rollbackTransactionStatement;
@property BOOL									transactionClosed;

- (void)addItem:(SRKTransactionElement*)item;
- (id)commit;
+ (SRKTransactionGroup*)createNewCollection;
+ (SRKTransactionGroup*)createEffectiveCollection;
+ (void)clearEffectiveTransaction;
+ (BOOL)isEfectiveTransaction;
+ (void)updateObjectForTransactionId:(NSString*)identifier withIndex:(NSNumber*)indexPosition newPrimaryKeyValue:(NSNumber*)pkValue;

@end
