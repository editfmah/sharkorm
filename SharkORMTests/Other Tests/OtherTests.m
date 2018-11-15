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


#import "OtherTests.h"

@implementation OtherTests

- (void)test_print_concommited_object {
    Person* p = [Person new];
    [p commit];
    NSLog(@"%@",p);
}

- (void)test_print_unconcommited_object {
    Person* p = [Person new];
    NSLog(@"%@",p);
}

- (void)test_asDictionary {
    Person* p = [Person new];
    
    p.age = 65;
    p.payrollNumber = 100001;
    p.Name = nil;
    NSDictionary* dict = [p asDictionary];
    
    NSLog(@"dict: %@", dict);
    
    XCTAssert([dict[@"Id"] isEqual:[NSNull null]], @"dict[Id] is wrong!");
    XCTAssert([dict[@"age"] isEqual:@(65)], @"dict[age] is wrong!");
    XCTAssert([dict[@"payrollNumber"] isEqual:@(100001)], @"dict[payrollNumber] is wrong!");
    XCTAssert([dict[@"Name"] isEqual:[NSNull null]], @"dict[Name] is wrong!");

    Person* p2 = [[Person alloc] initWithDictionary:dict];
    
    XCTAssert(p2.age == 65,@"failed to establish age");
    XCTAssert(p2.payrollNumber == 100001,@"failed to establish payrollNumber");
    XCTAssert(p2.Name == nil, @"failed to clear name");
}

@end
