//
//  SRKTransaction+Private.h
//  SharkORM
//
//  Created by Adrian Herridge on 15/12/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#ifndef SRKTransaction_Private_h
#define SRKTransaction_Private_h

#import "SharkORM.h"

typedef enum : NSUInteger {
    SRKTransactionFailed,
    SRKTransactionPassed,
    SRKTransactionBackstoreFailed,
    SRKTransactionLogicFailed,
} SRKTransactionStates;

@interface SRKTransaction ()

+ (void)blockUntilTransactionFinished;
+ (BOOL)transactionIsInProgress;
+ (void)addReferencedObjectToTransactionList:(id)referencedObject;
+ (void)startTransactionForDatabaseConnection:(NSString*)database;

@end

#endif /* SRKTransaction_Private_h */
