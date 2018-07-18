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


#import "Subclass.h"

@implementation Subclass

- (void)setupCommonData {
    
    [self cleardown];
    
    // setup some common data
    
    Department* d = [Department new];
    d.name = @"Test Department";
    
    SmallPerson* p = [SmallPerson new];
    p.Name = @"Adrian";
    p.age = 37;
    p.height = 177;
    p.department = d;
    [p commit];
    
    p = [SmallPerson new];
    p.Name = @"Neil";
    p.age = 34;
    p.department = d;
    p.height = 180;
    [p commit];
    
    p = [SmallPerson new];
    p.Name = @"Michael";
    p.age = 30;
    p.department = d;
    p.height = 179;
    [p commit];
    
}

- (void)test_subclass_where_query {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[SmallPerson query] where:@"age >= 34"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 2,@"incorrect number of results returned");
    
    r = [[SmallPerson query] where:@"height >= 178"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 2,@"incorrect number of results returned");
    
}

- (void)test_check_subclass_object {
    
    [self cleardown];
    
    SmallPerson* sp = [SmallPerson new];
    sp.height = 165;
    sp.Name = @"Adrian";
    [sp commit];
    
}

- (void)test_subclass_one_to_one_object_linking {
    
    [self setupCommonData];
    
    SmallPerson* p = [[[[SmallPerson query] limit:1] fetch] firstObject];
    XCTAssert(p, @"failed to retrieve a 'Person' entity when stored with Person->Deprtment->Location");
    XCTAssert(p.department, @"one-to-one related object was nil when checking property");
    XCTAssert([p.department.name isEqualToString:@"Test Department"], @"the correct related object was not loaded");
    
}


@end
