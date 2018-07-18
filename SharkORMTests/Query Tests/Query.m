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


#import "Query.h"

@implementation Query

- (void)setupCommonData {
    
    [self cleardown];
    
    // setup some common data
    
    Department* d = [Department new];
    d.name = @"Test Department";
    
    Department* d2 = [Department new];
    d2.name = @"Old Department";
    
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.age = 37;
    p.department = d;
    p.origDepartment = d2;
    [p commit];
    
    p = [Person new];
    p.Name = @"Neil";
    p.age = 34;
    p.department = d;
    p.origDepartment = d2;
    [p commit];
    
    p = [Person new];
    p.Name = @"Michael";
    p.age = 30;
    p.department = d;
    p.origDepartment = d2;
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
    
    NSArray* r = [[[Person query] order:@"Name"] distinct:@"Name"];
    XCTAssert(r, @"call to get distinct results failed");
    XCTAssert(r.count == 3, @"number of items returned from distinct call is incorrect");
    XCTAssert([[r objectAtIndex:0] isEqualToString:@"Adrian"], @"order by in distinct failed");
    XCTAssert([[r objectAtIndex:1] isEqualToString:@"Michael"], @"order by in distinct failed");
    XCTAssert([[r objectAtIndex:2] isEqualToString:@"Neil"], @"order by in distinct failed");
}

- (void)test_whereWithFormat_parameter_type_entity {
    
    [self setupCommonData];
    
    Department* d = [[[[Department query] where:@"name = 'Test Department'"] fetch] firstObject];
    
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
    
    SRKResultSet *r = [[Person query] where:@"Name LIKE ?" parameters:@[@"%cha%"]].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 1,@"incorrect number of results returned");
    XCTAssert([((Person*)[r objectAtIndex:0]).Name isEqualToString:@"Michael"],@"incorrect number of results returned");
    
    // test for case insensitivity
    r = [[Person query] where:@"Name LIKE ?" parameters:@[@"chA"]].fetch;
    
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
    XCTAssert(results.columnCount == 8, @"Raw query column count was incorrect given fixed data");
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
    
    SRKResultSet *r = [[[Person query] where:@"department.name='Test Department' AND location.locationName IS NULL"] order:@"department.name"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 3,@"incorrect number of results returned");
    
}

- (void)test_where_query_with_object_dot_notation_joins_not_named_as_entity {
    
    [self setupCommonData];
    
    SRKResultSet *r = [[Person query] where:@"origDepartment.name='Old Department' AND location.locationName IS NULL"].fetch;
    
    XCTAssert(r,@"Failed to return a result set");
    XCTAssert(r.count == 3,@"incorrect number of results returned");
    
}

- (void)test_batch_size_with_large_data_set {
    
    [self cleardown];
    
    Person* p1 = nil;
    Person* p2 = nil;
    Person* p3 = nil;
    Person* p4 = nil;
    
    for (int i=0; i < 10000; i++) {
        @autoreleasepool {
            Person* p = [Person new];
            p.Name = [NSString stringWithFormat:@"%@", @(rand() % 9999999999)];
            p.age = rand();
            p.seq = i;
            [p commit];
            if (i==50) {
                p1 = p;
            }
            if (i==1050) {
                p2 = p;
            }
            if (i==2050) {
                p3 = p;
            }
            if (i==9000) {
                p4 = p;
            }
        }
    }
    
    SRKResultSet* results = [[[Person query] batchSize:1000] fetch];
    int64_t count = results.count;
    
    XCTAssert(count > 0,@"batch count failed");
    XCTAssert(count == 10000,@"batch count failed");
    
    int i=0;
    for (Person* p in results) {
        if (i==50) {
            XCTAssert(p.age == p1.age,@"batch comparison failed");
        }
        if (i==1050) {
            XCTAssert(p.age == p2.age,@"batch comparison failed");
        }
        if (i==2050) {
            XCTAssert(p.age == p3.age,@"batch comparison failed");
        }
        if (i==9000) {
            XCTAssert(p.age == p4.age,@"batch comparison failed");
        }
        i++;
    }
    
}

- (void)test_date_parameters {
    
    [self cleardown];
    
    // fisrt should be excluded form the results
    MostObjectTypes* mo0 = [MostObjectTypes new];
    mo0.date = [NSDate date];
    [mo0 commit];
    [NSThread sleepForTimeInterval:0.1];
    
    NSDate* start = [NSDate date];
    [NSThread sleepForTimeInterval:0.1];
    
    MostObjectTypes* mo1 = [MostObjectTypes new];
    mo1.date = [NSDate date];
    [mo1 commit];
    
    [NSThread sleepForTimeInterval:0.1];
    
    MostObjectTypes* mo2 = [MostObjectTypes new];
    mo2.date = [NSDate date];
    [mo2 commit];
    
    [NSThread sleepForTimeInterval:0.1];
    int64_t count = [[[MostObjectTypes query] whereWithFormat:@"date >= %@ AND date <= %@", start, [NSDate date]] count];
    
    XCTAssert(count == 2, @"query with NSDate parameters failed");
    
}

- (void)test_nil_related_entity_as_parameter {
    
    [self cleardown];
    
    Person* p = [Person new];
    p.Name = @"Adrian";
    p.department = [Department new];
    p.department.name = @"Dev";
    [p commit];
    
    
    Department* d = [[[Department query] fetch] firstObject];
    [d remove];
    
    SRKResultSet* r = [[[Person query] whereWithFormat:@"department = %@", d] fetch];
    
}

@end
