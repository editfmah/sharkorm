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
#import "SRKObject+Private.h"
#import "SRKRegistry.h"
#import "SRKGlobals.h"

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

+ (BOOL)transactionIsInProgressForThisThread {
    if (transactionInProgress) {
        BOOL isMyTransaction = false;
        @synchronized (transactionThread) {
            isMyTransaction = (transactionThread == [NSThread currentThread]);
        }
        if (isMyTransaction) {
            return YES;
        }
    }
    return NO;
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

+ (void)failTransactionWithCode:(SRKTransactionStates)code {
    transactionResult = code;
}

+ (SRKTransactionStates)currentTransactionStatus {
    return transactionResult;
}

+ (void)transaction:(SRKTransactionBlockBlock)transaction withRollback:(SRKTransactionBlockBlock)rollback {
	
	if (transaction) {
        
        // loop indefinately so we can lock on a semaphore, the current transaction will in fact lock the transaction or block waiting.
        
        // all reads and writes will block if they are not within the current transaction, until it has completed.  At that point they will release.  Paralell calls to a transaction will also block.
        
        //TODO:  Base transaction on separate database connections so they can be independant and not foul external queries and updates.  For now we levae this as a single crunch point for reliability.
        
        while (true) {
            @synchronized (transactionSemaphore) {
                
                transactionResult = SRKTransactionPassed;
                transactionInProgress = YES;
                transactionThread = [NSThread currentThread];
                transaction();
                
                if (transactionResult != SRKTransactionPassed) {
                    
                    // now rollback all the SRKObjects
                    for (SRKObject* o in transactionReferencedObjects) {
                        // rollback the object using the SRKTransactionInfo.
                        [o rollback];
                    }
                    for (NSString* database in transactionReferencedDatabases) {
                        [SharkORM executeSQL:rollbackTransactionStatement inDatabase:database];
                    }
                    
                } else {
                    
                    for (NSString* database in transactionReferencedDatabases) {
                        [SharkORM executeSQL:commitTransactionStatement inDatabase:database];
                    }
                    
                    // now execute the event notifications for all objects within this transaction
                    for (SRKObject* o in transactionReferencedObjects) {
                        
                        // triger the global callbacks if they have been registered
                        
                        if (o.transactionInfo.eventType == SharkORMEventInsert) {
                            // now raise a global event
                            SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getInsertCallback];
                            if (callback) {
                                callback(o);
                            }
                        }
                        
                        if (o.transactionInfo.eventType == SharkORMEventUpdate) {
                            // now raise a global event
                            SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getUpdateCallback];
                            if (callback) {
                                callback(o);
                            }
                        }
                        
                        if (o.transactionInfo.eventType == SharkORMEventDelete) {
                            // now raise a global event
                            SRKGlobalEventCallback callback = [[SRKGlobals sharedObject] getDeleteCallback];
                            if (callback) {
                                callback(o);
                            }
                        }
                        
                        if (o.commitOptions.triggerEvents) {
                            SRKEvent* e = [SRKEvent new];
                            e.event = o.transactionInfo.eventType;
                            e.entity = o;
                            e.changedProperties = o.modifiedFieldNames;
                            [[SRKRegistry sharedInstance] broadcast:e];
                        }
                        o.transactionInfo = nil;
                    }
                    
                    // execute any post commit/remove blocks
                    
                    for (SRKObject* o in transactionReferencedObjects) {
                        if (o.transactionInfo.eventType == SharkORMEventInsert || o.transactionInfo.eventType == SharkORMEventUpdate ) {
                            if (o.commitOptions.postCommitBlock) {
                                o.commitOptions.postCommitBlock();
                            }
                        } else if (o.transactionInfo.eventType == SharkORMEventDelete) {
                            if (o.commitOptions.postRemoveBlock) {
                                o.commitOptions.postRemoveBlock();
                            }
                        }
                    }
                    
                }
                
                [transactionReferencedObjects removeAllObjects];
                [transactionReferencedDatabases removeAllObjects];
                transactionThread = nil;
                transactionInProgress = NO;
                
                if (transactionResult != SRKTransactionPassed) {
                    
                    // execute the rollback now the transaction is finished, because it will need to start a new one or may execute it's own DB updates.
                    
                    if (rollback) {
                        rollback();
                    }
                }
                
                break;
                
            }
        }

	}
	
}

@end
