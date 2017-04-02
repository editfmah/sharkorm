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
