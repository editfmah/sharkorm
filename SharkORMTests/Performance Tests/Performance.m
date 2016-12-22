//
//  Performance.m
//  SharkORM
//
//  Created by Adrian Herridge on 02/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Performance.h"

@implementation Performance

- (void)test_Sequential_Insert_Random_Query {
    
    srand(@([NSDate date].timeIntervalSince1970).intValue);
    
    @autoreleasepool {
        
        // small record tests
        
        for (int i=0; i < 1000; i++) {
            @autoreleasepool {
                Person* p = [Person new];
                p.Name = [NSString stringWithFormat:@"%@", @(rand() % 9999999999)];
                p.age = rand();
                p.seq = i;
                [p commit];
            }
        }
        
        for (int i=0; i < 5; i++) {
            @autoreleasepool {
                SRKResultSet* r = [[[Person query] where:@"seq > 300 AND seq < 800"] fetch];
                r = [[[Person query] where:@"seq > 300 AND seq < 3000"] fetch];
                r = [[[[Person query] where:@"seq > 400 AND seq < 450"] orderBy:@"age"]fetch];
                r = [[[Person query] where:@"seq > 200 AND seq < 400"] fetch];
                r = [[[[Person query] where:@"seq > 100 AND seq < 700"] orderByDescending:@"age"]fetch];
                r = [[[Person query] where:@"seq > 900 AND seq < 8000"] fetch];
            }
        }
        
        for (int i=0; i < 100; i++) {
            @autoreleasepool {
                SRKResultSet* r = [[[[Person query] whereWithFormat:@"seq = %i", rand() % 9999] limit:1] fetch];
                r = [[[Person query] whereWithFormat:@"seq > %i", rand() % 9999] fetch];
            }
        }
        
    }
    
}

@end
