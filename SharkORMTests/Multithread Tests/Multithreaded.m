//
//  Multithreaded.m
//  SharkORM
//
//  Created by Adrian Herridge on 15/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Multithreaded.h"

@implementation Multithreaded

- (void)test_multithreaded_insert_of_sequential_objects_x50 {
    
    [self cleardown];
    
    // now loop creating 50x simultanious insert operations
    int i=0;
    for (i=1; i<=50; i++) {
        __block int copyInt = i;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            Person* p = [Person new];
            p.age = copyInt;
            [p commit];
            
        });
    }
    
    // just wait until we can guarantee the inserts have finished, then we can test the output
    [NSThread sleepForTimeInterval:10];
    
    XCTAssert([[Person query] count] == 50, @"Failed to insert 50 records simultaniously");
    
    for (i=1; i<=50; i++) {
        XCTAssert(([[[Person query] whereWithFormat:@"age = %i", i] count] == 1), @"missing record when inserting simultanious objects");
    }
    
}

- (void)test_stress_insert_update_delete_objects_semi_sequntial_x50 {
    
    // there is no way to measure the random nature of this test, but we will look for crashes from mult threaded access
    
    [self cleardown];
    
    srand(@([NSDate date].timeIntervalSince1970).intValue);
    
    // setup the base level data.
    int i=0;
    for (i=1; i<=50; i++) {
        Person* p = [Person new];
        p.age = i;
        [p commit];
    }
    
    // now flood the insert / update / delete mechanisums
    
    // now loop creating 50x simultanious insert operations
    i=0;
    for (i=1; i<=50; i++) {
        __block int copyInt = i;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            Person* p = [Person new];
            p.age = copyInt;
            [p commit];
            
        });
    }
    
    // now loop creating 50x simultanious query/update operations
    i=0;
    for (i=1; i<=50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            SRKResultSet* results = [[Person query] fetch];
            Person* p = [results objectAtIndex:rand() % results.count];
            if (p) {
                p.age = rand() % 100;
                [p commit];
            }
            
        });
    }
    
    // now loop creating 50x simultanious query/delete operations
    i=0;
    for (i=1; i<=50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            SRKResultSet* results = [[Person query] fetch];
            Person* p = [results objectAtIndex:rand() % results.count];
            if (p) {
                [p remove];
            }
            
        });
    }
    
    // just wait until we can guarantee the inserts have finished, then we can test the output
    [NSThread sleepForTimeInterval:10];
    
}

- (void)test_stress_insert_update_delete_objects_grouped_x50 {
    
    // there is no way to measure the random nature of this test, but we will look for crashes from mult threaded access
    
    [self cleardown];
    
    srand(@([NSDate date].timeIntervalSince1970).intValue);
    
    // setup the base level data.
    int i=0;
    for (i=1; i<=50; i++) {
        Person* p = [Person new];
        p.age = i;
        [p commit];
    }
    
    // now flood the insert / update / delete mechanisums
    
    // now loop creating 50x simultanious insert operations
    i=0;
    for (i=1; i<=50; i++) {
        __block int copyInt = i;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            Person* p = [Person new];
            p.age = copyInt;
            [p commit];
            
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            SRKResultSet* results = [[Person query] fetch];
            Person* p = [results objectAtIndex:rand() % results.count];
            if (p) {
                p.age = rand() % 100;
                [p commit];
            }
            
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            SRKResultSet* results = [[Person query] fetch];
            Person* p = [results objectAtIndex:rand() % results.count];
            if (p) {
                [p remove];
            }
            
        });
        
    }
    
    // just wait until we can guarantee the inserts have finished, then we can test the output
    [NSThread sleepForTimeInterval:10];
    
}

@end
