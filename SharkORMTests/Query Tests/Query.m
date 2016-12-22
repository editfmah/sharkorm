//
//  Query.m
//  SharkORM
//
//  Created by Adrian Herridge on 14/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Query.h"

@implementation Query

- (void)test {

    
    
}

- (void)setupCommonData {
    
    [self cleardown];
    
    // setup some common data
    
    Department* d = [Department new];
    d.name = @"Test Department";
    
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
    
}

- (void)test_where_query {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] where:@"age >= 34"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 2,@"incorrect number of results returned");
    
}

- (void)test_whereWithFormat_query {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] whereWithFormat:@"age >= %@", @(34)].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 2,@"incorrect number of results returned");
    
}

- (void)test_count_query {
    
    [self setupCommonData];
    
    uint64_t r = [[Person query] whereWithFormat:@"age >= %@", @(34)].count;

    XCTAssert(r == 2,@"incorrect number of results returned");
    
}

- (void)test_sum_query {
    
    [self setupCommonData];
    
    double r = [[[Person query] whereWithFormat:@"age >= %@", @(34)] sumOf:@"age"];
    
    XCTAssert(r == 71, @"incorrect number of results returned");
    
}

- (void)test_distinct_query_string_value {
    
    [self setupCommonData];
    
    // duplicate some of the data
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    [p commit];
    
    p = [Person new];
    p.Name = @"Neil";
    p.age = 34;
    [p commit];
    
    NSArray* r = [[Person query] distinct:@"Name"];
    XCTAssert(r, @"call to get distinct results failed");
    XCTAssert(r.count == 3, @"number of items returned from distinct call is incorrect");
    XCTAssert([r containsObject:@"Adrian"] && [r containsObject:@"Michael"] && [r containsObject:@"Neil"], @"number of items returned from distinct call is incorrect");
    
}

- (void)test_distinct_query_string_value_order_by {
    
    [self setupCommonData];
    
    // duplicate some of the data
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    [p commit];
    
    p = [Person new];
    p.Name = @"Neil";
    p.age = 34;
    [p commit];
    
    NSArray* r = [[[Person query] orderBy:@"Name"] distinct:@"Name"];
    XCTAssert(r, @"call to get distinct results failed");
    XCTAssert(r.count == 3, @"number of items returned from distinct call is incorrect");
    XCTAssert([[r objectAtIndex:0] isEqualToString:@"Adrian"], @"order by in distinct failed");
    XCTAssert([[r objectAtIndex:1] isEqualToString:@"Michael"], @"order by in distinct failed");
    XCTAssert([[r objectAtIndex:2] isEqualToString:@"Neil"], @"order by in distinct failed");
}

- (void)test_whereWithFormat_parameter_type_entity {
    
    [self setupCommonData];
    
    Department* d = [[[Department query] fetch] firstObject];
    
    SRKResultSet *r = [[Person query] whereWithFormat:@"department = %@", d].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 3,@"incorrect number of results returned");
    
}

- (void)test_whereWithFormat_parameter_type_int {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] whereWithFormat:@"age = %i", 37].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 1,@"incorrect number of results returned");
    
}

- (void)test_whereWithFormat_parameter_type_string {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] whereWithFormat:@"Name = %@", @"Neil"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 1,@"incorrect number of results returned");
    
}

- (void)test_whereWithFormat_parameter_type_like {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] whereWithFormat:@"Name LIKE %@", makeLikeParameter(@"cha")].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 1,@"incorrect number of results returned");
    XCTAssert([((Person*)[r objectAtIndex:0]).Name isEqualToString:@"Michael"],@"incorrect number of results returned");
    
    // test for case insensitivity
    r = [[Person query] whereWithFormat:@"Name LIKE %@", makeLikeParameter(@"chA")].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    
    // this is a known bug/feature, SQLite's LIKE comparisons are case insensitive.
    // http://stackoverflow.com/questions/15480319/case-sensitive-and-insensitive-like-in-sqlite
    // TODO: descision to be made on weather this is an acceptable situation or whether we should change the default
    // XCTAssert(r.count == 0,@"incorrect number of results returned");
    
}

- (void)test_raw_query {
    
    [self setupCommonData];
    
    SRKRawResults* results = [SharkORM rawQuery:@"SELECT * FROM Person ORDER BY age;"];
    
    XCTAssert(results.rowCount == 3, @"Raw query row count was incorrect given fixed data");
    XCTAssert(results.columnCount == 7, @"Raw query column count was incorrect given fixed data");
    XCTAssert([((NSString*)[results valueForColumn:@"Name" atRow:0]) isEqualToString:@"Michael"], @"Raw query column count was incorrect given fixed data");
    
}

- (void)test_where_query_with_object_dot_notation_joins {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] where:@"department.name='Test Department' AND location.locationName IS NULL"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 3,@"incorrect number of results returned");
    
}

- (void)test_where_query_with_object_dot_notation_joins_order_by_on_joined_subproperty {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[[Person query] where:@"department.name='Test Department' AND location.locationName IS NULL"] orderBy:@"department.name"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 3,@"incorrect number of results returned");
    
}

@end
