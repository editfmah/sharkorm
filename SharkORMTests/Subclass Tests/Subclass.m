//
//  Subclass.m
//  SharkORM
//
//  Created by Adrian Herridge on 21/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

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

- (void)test_check_subclass_swift_object {
    
    [self cleardown];
    
    SmallPersonSwift* sp = [SmallPersonSwift new];
    sp.height = @(165);
    sp.Name = @"Adrian";
    [sp commit];
    
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
