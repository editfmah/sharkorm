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
                r = [[[[Person query] where:@"seq > 400 AND seq < 450"] order:@"age"]fetch];
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
