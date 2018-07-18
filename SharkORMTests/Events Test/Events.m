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


#import "Events.h"

@implementation Events

- (void)test_event_simple_object_update_event {
    
    [self cleardown];
    
    Person* p = [Person new];
    [p commit];
    __block BOOL updated = NO;
    
    [p registerBlockForEvents:SharkORMEventUpdate withBlock:^(SRKEvent *event) {
        updated = YES;
    } onMainThread:YES];
    
    p.Name = @"New name";
    [p commit];
    
    XCTAssert(updated, @"event failed to be raised for update.");
    
}

- (void)test_event_simple_object_delete_event {
    
    [self cleardown];
    
    Person* p = [Person new];
    [p commit];
    __block BOOL updated = NO;
    
    [p registerBlockForEvents:SharkORMEventDelete withBlock:^(SRKEvent *event) {
        updated = YES;
    } onMainThread:YES];
    
    [p remove];
    
    XCTAssert(updated, @"event failed to be raised for update.");
    
}

- (void)test_event_simple_entity_class_insert_event {
    
    [self cleardown];
    
    __block BOOL called = NO;
    
    SRKEventHandler* handler = [Person eventHandler];
    [handler registerBlockForEvents:SharkORMEventInsert withBlock:^(SRKEvent *event) {
        called = YES;
    } onMainThread:YES];
    
    Person* p = [Person new];
    [p commit];
    
    XCTAssert(called, @"event failed to be raised for insert");
    
}

- (void)test_event_simple_entity_class_update_not_insert_event {
    
    [self cleardown];
    
    __block BOOL called = NO;
    
    SRKEventHandler* handler = [Person eventHandler];
    [handler registerBlockForEvents:SharkORMEventUpdate withBlock:^(SRKEvent *event) {
        called = YES;
    } onMainThread:YES];
    
    Person* p = [Person new];
    [p commit];
    
    XCTAssert(!called, @"event raised for insert, but only monitoring update");
    
    
    p.Name = @"New Name";
    [p commit];
    
    XCTAssert(called, @"event failed to be raised for update");
    
}

- (void)test_event_simple_entity_class_bitwise_events {
    
    [self cleardown];
    
    __block BOOL called = NO;
    
    SRKEventHandler* handler = [Person eventHandler];
    [handler registerBlockForEvents:SharkORMEventUpdate|SharkORMEventDelete withBlock:^(SRKEvent *event) {
        called = YES;
    } onMainThread:YES];
    
    Person* p = [Person new];
    [p commit];
    
    XCTAssert(!called, @"event raised for insert, but only monitoring update|delete");
    
    [p remove];
    
    XCTAssert(called, @"event failed to be raised for delete despite monitoring for update|delete");
    
}

- (void)test_event_simple_object_update_event_multithreaded {
    
    [self cleardown];
    
    Person* p = [Person new];
    [p commit];
    __block BOOL updated = NO;
    
    [p registerBlockForEvents:SharkORMEventUpdate withBlock:^(SRKEvent *event) {
        updated = YES;
    } onMainThread:NO]; // can't use main thread here because it clashes with the sleep on the same thread.
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        p.Name = @"New name";
        [p commit];
        
    });
    
    [NSThread sleepForTimeInterval:2];
    
    XCTAssert(updated, @"event failed to be raised for update from different thread.");
    
}

- (void)test_global_event_blocks {
    
    [self cleardown];
    
    __block int insertCount = 0;
    __block int updateCount = 0;
    __block int deleteCount = 0;
    
    [SharkORM setInsertCallbackBlock:^(SRKEntity * _Nonnull entity) {
        if ([[entity.class description] isEqualToString:@"Person"]) {
            insertCount += 1;
        }
    }];
    
    [SharkORM setUpdateCallbackBlock:^(SRKEntity * _Nonnull entity) {
        if ([[entity.class description] isEqualToString:@"Person"]) {
            updateCount += 1;
        }
    }];
    
    [SharkORM setDeleteCallbackBlock:^(SRKEntity * _Nonnull entity) {
        if ([[entity.class description] isEqualToString:@"Person"]) {
            deleteCount += 1;
        }
    }];
    
    Person* p = [Person new];
    p.Name = @"testing 123";
    [p commit];
    
    XCTAssert(insertCount == 1 && updateCount == 0 && deleteCount == 0 ,@"failed to trigger event correctly");
    p.Name = @"testing 321";
    [p commit];
    
    XCTAssert(insertCount == 1 && updateCount == 1 && deleteCount == 0 ,@"failed to trigger event correctly");
    
    [p remove];
    
    XCTAssert(insertCount == 1 && updateCount == 1 && deleteCount == 1 ,@"failed to trigger event correctly");
    
    insertCount = 0;
    updateCount = 0;
    deleteCount = 0;
    
    p = [Person new];
    
    [SRKTransaction transaction:^{
    
        // insert
        p.Name = @"testing 123";
        [p commit];
        
    } withRollback:^{
        
        
        
    }];
    
    [SRKTransaction transaction:^{
        
        // update
        p.Name = @"testing 321";
        [p commit];
        
    } withRollback:^{
        
        
        
    }];
    
    [SRKTransaction transaction:^{
        
        // delete
        [p remove];
        
    } withRollback:^{
        
        
        
    }];
    
    XCTAssert(insertCount == 1 && updateCount == 1 && deleteCount == 1 ,@"failed to trigger event correctly");
    
    insertCount = 0;
    updateCount = 0;
    deleteCount = 0;
    
    [SRKTransaction transaction:^{
        
        Person* p = [Person new];
        p.Name = @"testing 123";
        [p commit];
        p.Name = @"testing 321";
        [p commit];
        [p remove];
        
    } withRollback:^{
        
    // a transaction only holds a "final" state for an object, which in this case is delete.
    XCTAssert(insertCount == 0 && updateCount == 0 && deleteCount == 1 ,@"failed to trigger event correctly");
        
        
    }];
    
}

@end
