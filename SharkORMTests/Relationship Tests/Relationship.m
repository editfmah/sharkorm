//
//  Relationship.m
//  SharkORM
//
//  Created by Adrian Herridge on 15/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Relationship.h"

@implementation Relationship

- (void)setupCommonData {
    
    [self cleardown];
    
    // setup some common data
    
    Location* l = [Location new];
    l.locationName = @"San Francisco";
    [l commit];
    
    Department* d = [Department new];
    d.name = @"Test Department";
    d.location = l;
    
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    p.department = d;
    [p commit];
    
    p = [Person new];
    p.Name = @"Neil";
    p.age = 34;
    p.department = d;
    [p commit];
    
    p = [Person new];
    p.Name = @"Michael";
    p.age = 30;
    p.department = d;
    [p commit];
    
    p = [Person new];
    p.Name = @"Sarah";
    p.age = 34;
    [p commit];
    
}

- (void)test_one_to_one_object_linking {
    
    [self setupCommonData];
    
    Person* p = [[[[Person query] limit:1] fetch] firstObject];
    XCTAssert(p, @"failed to retrieve a 'Person' entity when stored with Person->Deprtment->Location");
    XCTAssert(p.department, @"one-to-one related object was nil when checking property");
    XCTAssert([p.department.name isEqualToString:@"Test Department"], @"the correct related object was not loaded");
    
}

- (void)test_one_to_one_to_one_object_linking {
    
    [self setupCommonData];
    
    Person* p = [[[[Person query] limit:1] fetch] firstObject];
    XCTAssert(p, @"failed to retrieve a 'Person' entity when stored with Person->Deprtment->Location");
    XCTAssert(p.department, @"one-to-one related object was nil when checking property");
    XCTAssert(p.department.location, @"one-to-one-to-one related object was nil when checking property");
    XCTAssert([p.department.location.locationName isEqualToString:@"San Francisco"], @"the correct related object was not loaded");
    
}

- (void)test_one_to_one_object_linking_no_related_object {
    
    [self setupCommonData];
    
    Person* p = [[[[[Person query] where:@"Name = 'Sarah'"] limit:1] fetch] firstObject];
    XCTAssert(p, @"failed to retrieve a 'Person' entity when stored with Person->Deprtment->Location");
    XCTAssert(p.department == nil, @"one-to-one related object was not empty when checking property");
    XCTAssert(![p.department.name isEqualToString:@"Test Department"], @"an object was loaded, when there should be nothing");
    
}

- (void)test_one_to_one_and_back_to_one_circular_reference {
    
    [self cleardown];
    
    // setup some common data
    
    Location* l = [Location new];
    l.locationName = @"San Francisco";
    [l commit];
    
    Department* d = [Department new];
    d.name = @"Test Department";
    d.location = l;

    // create the problem
    l.department = d;
    
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    p.department = d;
    p.location = l;
    [p commit];
    
    Person* p2 = [[[Person query] fetch] firstObject];
    XCTAssert(p2, @"failed to retrieve a 'Person' entity when stored with Person->Deprtment->Location");
    XCTAssert(p2.department, @"one-to-one related object was not empty when checking property");
    XCTAssert([p2.department.name isEqualToString:@"Test Department"], @"an object was loaded, when there should be nothing");
    XCTAssert(p2.department.location, @"one-to-one related object was not empty when checking property");
    XCTAssert([p2.department.location.locationName isEqualToString:@"San Francisco"], @"an object was loaded, when there should be nothing");
    XCTAssert(p2.department.location.department, @"one-to-one related object was not empty when checking property");
    XCTAssert([p2.department.location.department.name isEqualToString:@"Test Department"], @"an object was loaded, when there should be nothing");
    XCTAssert(p2.location, @"one-to-one related object was not empty when checking property");
    XCTAssert([p2.location.locationName isEqualToString:@"San Francisco"], @"an object was loaded, when there should be nothing");
}

@end
