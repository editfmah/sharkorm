//
//  Events.m
//  SharkORM
//
//  Created by Adrian Herridge on 15/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

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

@end
