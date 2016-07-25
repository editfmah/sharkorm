//
//  Joins.m
//  SharkORM
//
//  Created by Adrian Herridge on 17/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Joins.h"

@implementation Joins

- (void)setupData {
    
    [self cleardown];
    
    Location* l = [Location new];
    l.locationName = @"Alton";
    
    Department* d = [Department new];
    d.name = @"Development";
    d.location = l;
    
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    p.department = d;
    p.location = l;
    [p commit];
    
}

- (void)test_single_join {
    
    [self setupData];
    
    // pull out a single object but use join to join to the department class and not the relationship
    Person * p = [[[[Person query] joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"] fetch] firstObject];
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([p.joinedResults objectForKey:@"Department.name"],@"join failed, no results returned for first join");
}

- (void)test_multiple_join {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[Person query]
                    joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"location" targetParameter:@"Id"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([[p.joinedResults objectForKey:@"Department.name"] isEqualToString:@"Development"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isEqualToString:@"Alton"],@"join failed, no results returned for second join");
}

- (void)test_multiple_join_with_fail_on_second_join {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[Person query]
                     joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"Name" targetParameter:@"Id"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([p.joinedResults objectForKey:@"Department.name"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isKindOfClass:[NSNull class]],@"join failed, no results returned for second join");
}

- (void)test_multiple_join_with_fail_on_second_join_test_for_null_in_where {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[[Person query]
                      where:@"Location.Id IS NULL"]
                     joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"Name" targetParameter:@"Id"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([p.joinedResults objectForKey:@"Department.name"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isKindOfClass:[NSNull class]],@"join failed, no results returned for first join");
}

- (void)test_multiple_join_with_joined_table_referenced_in_where {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[[Person query]
                     joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"location" targetParameter:@"Id"]
                    where:@"Location.locationName = 'Alton'"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([[p.joinedResults objectForKey:@"Department.name"] isEqualToString:@"Development"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isEqualToString:@"Alton"],@"join failed, no results returned for second join");
}

- (void)test_multiple_join_chaining_join_one_and_two {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[Person query]
                     joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Id"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([[p.joinedResults objectForKey:@"Department.name"] isEqualToString:@"Development"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isEqualToString:@"Alton"],@"join failed, no results returned for second join");
}

- (void)test_multiple_join_specifying_fully_qualified_field_names {
    
    [self setupData];
    
    // pull out a single object but use 2 joins to join to the department &  class and not the relationship
    Person * p = [[[[[Person query]
                     joinTo:[Department class] leftParameter:@"Person.department" targetParameter:@"Department.Id"]
                    joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Location.Id"]
                   fetch]
                  firstObject];
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([[p.joinedResults objectForKey:@"Department.name"] isEqualToString:@"Development"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isEqualToString:@"Alton"],@"join failed, no results returned for second join");
}

- (void)test_where_query_with_object_dot_notation_joins_and_normal_joins {
    
    [self setupData];
    
    SRKResultSet *r = [[[[Person query] where:@"department.name='Development' AND location.locationName = 'Alton' "]
                       joinTo:[Department class] leftParameter:@"Person.department" targetParameter:@"Department.Id"]
                        joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Location.Id"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 1,@"incorrect number of results returned");
    
    Person* p = r.firstObject;
    
    XCTAssert(p, @"failed to retrieve and object when using a single join");
    XCTAssert([[p.joinedResults objectForKey:@"Department.name"] isEqualToString:@"Development"],@"join failed, no results returned for first join");
    XCTAssert([[p.joinedResults objectForKey:@"Location.locationName"] isEqualToString:@"Alton"],@"join failed, no results returned for second join");
}


@end
