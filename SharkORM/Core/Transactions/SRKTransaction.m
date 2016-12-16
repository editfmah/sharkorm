//    MIT License
//
//    Copyright (c) 2016 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SharkORM+Private.h"
#import "SRKTransaction+Private.h"

static id                       transactionSemaphore;
static BOOL                     transactionInProgress;
static SRKTransactionStates     transactionResult;
static NSMutableArray*          transactionReferencedObjects;
static NSMutableArray*          transactionReferencedDatabases;
static NSThread*                transactionThread;

#define startTransactionStatement @"BEGIN TRANSACTION"
#define commitTransactionStatement @"COMMIT"
#define rollbackTransactionStatement @"ROLLBACK"

// C-Style transaction status macro
void SRKFailTransaction() {
    transactionResult = SRKTransactionFailed;
}

@implementation SRKTransaction

+ (void)initialize {
    transactionSemaphore = [NSObject new];
    transactionInProgress = NO;
    transactionReferencedObjects = [NSMutableArray new];
    transactionReferencedDatabases = [NSMutableArray new];
}

+ (void)blockUntilTransactionFinished {
    if (transactionThread) {
        BOOL isMyTransaction = false;
        @synchronized (transactionThread) {
            isMyTransaction = (transactionThread == [NSThread currentThread]);
        }
        if (!isMyTransaction) {
            // wait here, until the transaction is complete.
            @synchronized (transactionSemaphore) {
            }
        }
    }
}

+ (BOOL)transactionIsInProgress {
    return transactionInProgress;
}

+ (void)addReferencedObjectToTransactionList:(id)referencedObject {
    [transactionReferencedObjects addObject:referencedObject];
}

+ (void)startTransactionForDatabaseConnection:(NSString *)database {
    if ([[transactionReferencedDatabases componentsJoinedByString:@"|"] rangeOfString:database].location == NSNotFound) {
        [transactionReferencedDatabases addObject:database];
        [SharkORM executeSQL:startTransactionStatement inDatabase:database];
    }
}

+ (void)transaction:(SRKTransactionBlockBlock)transaction withRollback:(SRKTransactionBlockBlock)rollback {
	
	if (transaction) {
        
        // loop indefinately so we can lock on a semaphore, the current transaction will in fact lock the transaction or block waiting.
        
        // all reads and writes will block if they are not within the current transaction, until it has completed.  At that point they will release.
        
        //TODO:  Base transaction on separate database connections so they can be independant and not foul external queries and updates.  For now we levae this as a single crunch point for reliability.
        
        while (true) {
            @synchronized (transactionSemaphore) {
                
                transactionResult = SRKTransactionPassed;
                transactionThread = [NSThread currentThread];
                transaction();
                
                if (transactionResult != SRKTransactionPassed) {
                    if (rollback) {
                        rollback();
                    }
                    // now rollback all the SRKObjects
                    for (SRKObject* o in transactionReferencedObjects) {
                        //[o rollback];
                    }
                    for (NSString* database in transactionReferencedDatabases) {
                        [SharkORM executeSQL:rollbackTransactionStatement inDatabase:database];
                    }
                } else {
                    for (NSString* database in transactionReferencedDatabases) {
                        [SharkORM executeSQL:commitTransactionStatement inDatabase:database];
                    }
                }
                
                [transactionReferencedObjects removeAllObjects];
                [transactionReferencedDatabases removeAllObjects];
                transactionThread = nil;
                transactionInProgress = NO;
                break;
                
            }
        }

	}
	
}

@end
