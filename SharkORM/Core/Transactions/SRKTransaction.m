//
//  SRKTransaction.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SRKTransactionGroup.h"
#import "SharkORM.h"

@implementation SRKTransaction

+ (void)privateTransaction:(SRKTransactionBlockBlock)transaction withRollback:(SRKTransactionBlockBlock)rollback {
	
	if (transaction) {
		SRKTransactionGroup* c = [SRKTransactionGroup createNewCollection];
		transaction();
		if(![c commit]) {
			if (rollback) {
				rollback();
			}
		}
	}
	
}

+ (void)transaction:(SRKTransactionBlockBlock)transaction withRollback:(SRKTransactionBlockBlock)rollback {
	
	if (transaction) {
		SRKTransactionGroup* c = [SRKTransactionGroup createEffectiveCollection];
		transaction();
		if(![c commit]) {
			if (rollback) {
				rollback();
			}
		}
		[SRKTransactionGroup clearEffectiveTransaction];
	}
	
}

@end