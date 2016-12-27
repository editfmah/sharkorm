//
//  Persistence.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "Transactions.h"

@implementation Transactions

- (void)test_Simple_Object_Insert {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        Person* p = [Person new];
        BOOL result = [p commit];
        XCTAssert(result,@"Failed to insert simple object (without values)");
        
    } withRollback:^{
        
    }];
    
    XCTAssert([Person query].count, @"BOOL <return value> from commit was TRUE but the count on the table was 0");
    
}

- (void)test_Simple_Object_Update {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        Person* p = [Person new];
        p.Name = @"Adrian";
        BOOL result = [p commit];
        if (result) {
            Person* p2 = [[Person query] fetch].firstObject;
            if (p2) {
                p2.Name = @"Sarah";
                XCTAssert([p2 commit],@"Failed to update existing record with new values");
                Person* p3 = [[Person query] fetch].firstObject;
                XCTAssert([p3.Name isEqualToString:@"Sarah"],@"Non current value retrieved from store");
            } else {
                XCTAssert(p2,@"Object which was believed to be persisted, failed to be retrieved");
            }
        } else {
            XCTAssert(result,@"Failed to insert simple object (without values)");
        }
        
    } withRollback:^{
        
    }];
    
    
    
}

- (void)test_Simple_Object_Delete {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
    
        Person* p = [Person new];
        BOOL result = [p commit];
        if (result) {
            [[[Person query] fetch] removeAll];
            XCTAssert([Person query].count == 0, @"'removeAll' called, but objects remain in table");
        } else {
            XCTAssert(result,@"Failed to insert simple object (without values)");
        }
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Multiple_Object_Insert {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        Person* p1 = [Person new];
        Person* p2 = [Person new];
        Person* p3 = [Person new];
        
        [p1 commit];
        [p2 commit];
        [p3 commit];
        
        XCTAssert([Person query].count == 3, @"Insert 3 records inline failed");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Single_Object_Insert_Multiple_Times {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        Person* p1 = [Person new];
        
        [p1 commit];
        [p1 commit];
        [p1 commit];
        
        XCTAssert([Person query].count == 1, @"Insert 1 record 3 times failed");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Nested_Object_Insert {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        Person* p = [Person new];
        p.Name = @"New Person";
        p.department = [Department new];
        p.department.name = @"New Department";
        [p commit];
        
        XCTAssert([Person query].count == 1, @"Insert 1 record with a related/embedded object has failed");
        XCTAssert([Department query].count == 1, @"Insert 1 related record via a parent object");
        
        // actually check the correct object exists
        Department* d = [[[Department query] fetch] firstObject];
        XCTAssert(d != nil, @"Department object not retrieved");
        XCTAssert([d.name isEqualToString:@"New Department"], @"Invalid 'name' value in department object");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Nested_Object_Update {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        Person* p = [Person new];
        p.Name = @"New Person";
        p.department = [Department new];
        p.department.name = @"New Department";
        [p commit];
        
        XCTAssert([Person query].count == 1, @"Insert 1 record with a related/embedded object has failed");
        XCTAssert([Department query].count == 1, @"Insert 1 related record via a parent object");
        
        // actually check the correct object exists
        Department* d = [[[Department query] fetch] firstObject];
        XCTAssert(d != nil, @"Department object not retrieved");
        XCTAssert([d.name isEqualToString:@"New Department"], @"Invalid 'name' value in department object");
        
        // now check persistence of an update to a related object when commit is called on the parent object
        p.department.name = @"New Name";
        [p commit];
        
        d = [[[Department query] fetch] firstObject];
        XCTAssert(d != nil, @"Department object not retrieved");
        XCTAssert([d.name isEqualToString:@"New Name"], @"Invalid 'name' value in department object after persistence call to parent object");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Simple_Object_Insert_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        PersonSwift* p = [PersonSwift new];
        BOOL result = [p commit];
        XCTAssert(result,@"Failed to insert simple object (without values)");
        XCTAssert([PersonSwift query].count, @"BOOL <return value> from commit was TRUE but the count on the table was 0");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Simple_Object_Update_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        PersonSwift* p = [PersonSwift new];
        p.Name = @"Adrian";
        BOOL result = [p commit];
        if (result) {
            PersonSwift* p2 = [[PersonSwift query] fetch].firstObject;
            if (p2) {
                p2.Name = @"Sarah";
                XCTAssert([p2 commit],@"Failed to update existing record with new values");
                PersonSwift* p3 = [[PersonSwift query] fetch].firstObject;
                XCTAssert([p3.Name isEqualToString:@"Sarah"],@"Non current value retrieved from store");
            } else {
                XCTAssert(p2,@"Object which was believed to be persisted, failed to be retrieved");
            }
        } else {
            XCTAssert(result,@"Failed to insert simple object (without values)");
        }
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Simple_Object_Delete_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        PersonSwift* p = [PersonSwift new];
        BOOL result = [p commit];
        if (result) {
            [[[PersonSwift query] fetch] removeAll];
            XCTAssert([PersonSwift query].count == 0, @"'removeAll' called, but objects remain in table");
        } else {
            XCTAssert(result,@"Failed to insert simple object (without values)");
        }
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Multiple_Object_Insert_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        PersonSwift* p1 = [PersonSwift new];
        PersonSwift* p2 = [PersonSwift new];
        PersonSwift* p3 = [PersonSwift new];
        
        [p1 commit];
        [p2 commit];
        [p3 commit];
        
        XCTAssert([PersonSwift query].count == 3, @"Insert 3 records inline failed");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Single_Object_Insert_Multiple_Times_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
       
        PersonSwift* p1 = [PersonSwift new];
        
        [p1 commit];
        [p1 commit];
        [p1 commit];
        XCTAssert([PersonSwift query].count == 1, @"Insert 1 record 3 times failed");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_Nested_Object_Insert_Swift {
    
    [self cleardown];
    
    __block BOOL finished = NO;
    
    [SRKTransaction transaction:^{
       
        PersonSwift* p = [PersonSwift new];
        p.Name = @"New Person";
        p.department = [DepartmentSwift new];
        p.department.name = @"New Department";
        [p commit];
        
        finished = YES;
        
    } withRollback:^{
        
    }];
    
    while (!finished) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([PersonSwift query].count == 1, @"Insert 1 record with a related/embedded object has failed");
    XCTAssert([DepartmentSwift query].count == 1, @"Insert 1 related record via a parent object");
    
    // actually check the correct object exists
    DepartmentSwift* d = [[[DepartmentSwift query] fetch] firstObject];
    XCTAssert(d != nil, @"Department object not retrieved");
    XCTAssert([d.name isEqualToString:@"New Department"], @"Invalid 'name' value in department object");
    
}

- (void)test_Nested_Object_Insert_Swift_created_outside_transaction {
    
    [self cleardown];
    
    __block BOOL finished = NO;
    
    PersonSwift* p = [PersonSwift new];
    p.Name = @"New Person";
    [p commit];
    
    [SRKTransaction transaction:^{
        
        
        p.department = [DepartmentSwift new];
        p.department.name = @"New Department";
        [p commit];
        
        finished = YES;
        
    } withRollback:^{
        
    }];
    
    while (!finished) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([PersonSwift query].count == 1, @"Insert 1 record with a related/embedded object has failed");
    XCTAssert([DepartmentSwift query].count == 1, @"Insert 1 related record via a parent object");
    
    // actually check the correct object exists
    DepartmentSwift* d = [[[DepartmentSwift query] fetch] firstObject];
    XCTAssert(d != nil, @"Department object not retrieved");
    XCTAssert([d.name isEqualToString:@"New Department"], @"Invalid 'name' value in department object");
    
}

- (void)test_Nested_Object_Update_Swift {
    
    [self cleardown];
    
    [SRKTransaction transaction:^{
        
        PersonSwift* p = [PersonSwift new];
        p.Name = @"New Person";
        p.department = [DepartmentSwift new];
        p.department.name = @"New Department";
        [p commit];
        
        XCTAssert([PersonSwift query].count == 1, @"Insert 1 record with a related/embedded object has failed");
        XCTAssert([DepartmentSwift query].count == 1, @"Insert 1 related record via a parent object");
        
        // actually check the correct object exists
        DepartmentSwift* d = [[[DepartmentSwift query] fetch] firstObject];
        XCTAssert(d != nil, @"Department object not retrieved");
        XCTAssert([d.name isEqualToString:@"New Department"], @"Invalid 'name' value in department object");
        
        // now check persistence of an update to a related object when commit is called on the parent object
        p.department.name = @"New Name";
        [p commit];
        
        d = [[[DepartmentSwift query] fetch] firstObject];
        XCTAssert(d != nil, @"Department object not retrieved");
        XCTAssert([d.name isEqualToString:@"New Name"], @"Invalid 'name' value in department object after persistence call to parent object");
        
        
    } withRollback:^{
        
    }];

}

- (void)test_all_object_types {
    
    [SRKTransaction transaction:^{
       
        MostObjectTypes* ob = [MostObjectTypes new];
        ob.number = @(42);
        ob.array = @[@(1),@(2),@(3)];
        ob.date = [NSDate date];
        ob.dictionary = @{@"one" : @(1), @"two" : @(2)};
        ob.intvalue = 42;
        ob.floatValue = 42.424242f;
        ob.doubelValue = 1234567.1234567;
        [ob commit];
        
    } withRollback:^{
        
    }];
    
}

- (void)test_string_pk_object {
    
    [SRKTransaction transaction:^{
       
        StringIdObject* obj = [StringIdObject new];
        obj.value = @"test value];";
        
        // there should not be a UUID yet for the PK column
        XCTAssert(obj.Id == nil, @"Primary key had been generated prior to insertion into data store");
        [obj commit];
        XCTAssert(obj.Id != nil, @"Primary key had not been generated post insertion into data store");
        
        StringIdObject* o2 = [StringIdObject objectWithPrimaryKeyValue:obj.Id];
        XCTAssert(o2 != nil, @"Retrieval of object with a string PK value failed");
        
    } withRollback:^{
        
    }];
    
}

- (void)test_insert_cleandown_isolation {
    
    [self cleardown];
    __block BOOL first = false;
    
    // now test isolation within a transaction.  Insert 1k then delete records within a transaction, and test a count outside.  It should always be zero.
    first = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            for (int i=0; i < 1000; i++) {
                Person* p1 = [Person new];
                p1.age = i;
                [p1 commit];
            }
            
            for (Person* p in [[Person query] fetch]) {
                [p remove];
            }
            
            first = YES;
        } withRollback:^{
            
        }];
        
    });
    
    while (!first) {
        
        // test for leakage to outside the transaction
        u_int64_t count = [[Person query] count];
        if (count > 0) {
            XCTAssert(count == 0, @"Writes from within a transaction leaked out to an isolated thread");
        }
        
    }
    
}

- (void)test_delete_isolation {
    
    [self cleardown];
    __block BOOL first,second,querycomplete = false;
    
    // start with 1000 records
    for (int i=0; i < 1000; i++) {
        Person* p1 = [Person new];
        p1.age = i;
        [p1 commit];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            SRKResultSet* results = [[Person query] fetch];
            querycomplete = YES;
            for (Person* obj in results) {
                [obj remove];
            }
            first = YES;
        } withRollback:^{
            
        }];
        
    });
    
    while (!querycomplete) {
        [NSThread sleepForTimeInterval:0.05];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            for (int i=0; i < 1000; i++) {
                Person* p1 = [Person new];
                p1.age = i;
                [p1 commit];
            }
            second = YES;
        } withRollback:^{
            
        }];
        
        
    });
    
    while (!first || !second) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    int64_t count = [Person query].count;
    
    XCTAssert(count == 1000, @"count != 1k records, started 1k, inserted another 1k in a transaction, deleted 1k from original");
    
}

- (void)test_insert_isolation {
    
    [self cleardown];
    __block BOOL first = false;
    
    // now test isolation within a transaction.  Insert 1k records within a transaction, and test a count outside.  It should jump from 0 to 1k without a gap.
    
    first = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            for (int i=0; i < 1000; i++) {
                Person* p1 = [Person new];
                p1.age = i;
                [p1 commit];
            }
            first = YES;
        } withRollback:^{
            
        }];
        
    });
    
    [NSThread sleepForTimeInterval:0.1];
    
    while (!first) {
        
        // test for leakage to outside the transaction
        u_int64_t count = [[Person query] count];
        if (count > 0 && count < 1000) {
            XCTAssert((count == 0 || count == 1000), @"Writes from within a transaction leaked out to an isolated thread");
        }
        
    }

    
}

- (void)test_paralell_transactions {
    
    [self cleardown];
    __block BOOL first,second = false;
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            for (int i=0; i < 1000; i++) {
                Person* p1 = [Person new];
                p1.age = i;
                [p1 commit];
            }
        } withRollback:^{
            
        }];
        first = YES;
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SRKTransaction transaction:^{
            for (int i=0; i < 1000; i++) {
                Person* p1 = [Person new];
                p1.age = i;
                [p1 commit];
            }
        } withRollback:^{
            
        }];
        second = YES;
    });
    
    while (!first || !second) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([Person query].count == 2000, @"count != 2k records withing a paralell transaction");
    
    [self cleardown];
    
    
}

- (void)test_event_notifications_within_transaction {
    
    [self cleardown];
    __block BOOL first,second = false;
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            Person* p1 = [Person new];
            [p1 commit];
            p1.age = 127;
            [p1 registerBlockForEvents:SharkORMEventUpdate withBlock:^(SRKEvent *event) {
                    second = YES;
            } onMainThread:NO];
            [p1 commit];
        } withRollback:^{
            
        }];
        first = YES;
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first || !second) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"event notification failed from within a transaction");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            [p1 commit];
            SRKResultSet* r = [[[Person query] whereWithFormat:@"aglew = 127" withParameters:nil] fetch];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Person query] whereWithFormat:@"age = 100" withParameters:nil] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.age == 100, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes_no_commit {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            SRKResultSet* r = [[[Person query] whereWithFormat:@"aglew = 127" withParameters:nil] fetch];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert(p1.age == 100, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes_manual_error {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            [p1 commit];
            SRKFailTransaction();
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Person query] whereWithFormat:@"age = 100" withParameters:nil] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.age == 100, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes_raw_sql_fail {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            [p1 commit];
            [SharkORM rawQuery:@"balls"];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Person query] whereWithFormat:@"age = 100" withParameters:nil] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.age == 100, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_serial_transaction_rollback_value {
    
    [self cleardown];
    
    __block BOOL first,second, third = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            [p1 commit];
            SRKFailTransaction();
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    p1.age = 101;
    [p1 commit];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 128;
            [p1 commit];
            SRKFailTransaction();
            third = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    startTime = [[NSDate date] timeIntervalSince1970];
    while (!third) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Person query] whereWithFormat:@"age = 101" withParameters:nil] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.age == 101, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_serial_transaction_rollback_value_first_passes_second_fails {
    
    [self cleardown];
    
    __block BOOL first,second, third = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 127;
            [p1 commit];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    p1.age = 101;
    [p1 commit];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.age = 128;
            [p1 commit];
            SRKFailTransaction();
            third = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    startTime = [[NSDate date] timeIntervalSince1970];
    while (!third) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Person query] whereWithFormat:@"age = 101" withParameters:nil] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.age == 101, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes_embedded_objects {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    p1.department = [Department new];
    p1.department.name = @"test department";
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.department.name = @"new name";
            [p1 commit];
            
            SRKResultSet* r = [[[Person query] whereWithFormat:@"aglew = 127" withParameters:nil] fetch];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Department query] whereWithFormat:@"name = %@" withParameters:@[@"test department"]] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");

    [self cleardown];
    
}

- (void)test_failure_within_transaction_rolls_back_changes_change_relationship {
    
    [self cleardown];
    
    __block BOOL first,second = false;
    
    Person* p1 = [Person new];
    p1.age = 100;
    Department* d1 = [Department new];
    d1.name = @"D1";
    p1.department = d1;
    [p1 commit];
    
    // now start two simultanious transactions that will both only contain their own records.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [SRKTransaction transaction:^{
            
            p1.department = [Department new];
            p1.department.name = @"D2";
            [p1 commit];
            SRKResultSet* r = [[[Person query] whereWithFormat:@"aglew = 127" withParameters:nil] fetch];
            first = YES;
            
        } withRollback:^{
            
            second = YES;
            
        }];
        
    });
    
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    while (!first) {
        if (([[NSDate date] timeIntervalSince1970] - startTime) > 10) {
            XCTAssert(1==2, @"transaction error condition failed");
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    
    XCTAssert([[[Department query] whereWithFormat:@"name = %@" withParameters:@[@"D1"]] count] == 1, @"transaction error condition failed, transation that should have been aborted was commited");
    XCTAssert([[[Department query] whereWithFormat:@"name = %@" withParameters:@[@"D2"]] count] == 0, @"transaction error condition failed, transation that should have been aborted was commited");
    
    XCTAssert(second == YES, @"rollback block was not triggered");
    XCTAssert(p1.department == d1, @"object values were not restored to pre transaction states");
    
    [self cleardown];
    
}



@end
