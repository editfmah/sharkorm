//
//  RawQueryTests.m
//  SharkORMTests
//
//  Created by Adrian Herridge on 20/07/2018.
//  Copyright © 2018 Adrian Herridge. All rights reserved.
//

#import "RawQueryTests.h"

@implementation RawQueryTests

- (void)test_raw_query {
    
    [SharkORM rawQuery:@"DROP TABLE IF EXISTS RawQueryTest;"];
    [SharkORM rawQuery:@"CREATE TABLE RawQueryTest (Id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT, numValue INTEGER, blobValue BLOB);"];
    
    XCTAssert([SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] != nil, @"Raw Query object was nil");
    
    XCTAssert([SharkORM rawQuery:@"SELECT * FROM RawQueryTest"].rowCount == 0, @"RawQuery, row count was incorrect");
    
    [SharkORM rawQuery:@"INSERT INTO RawQueryTest (value, numValue) VALUES ('testing123',123);"];
    XCTAssert([SharkORM rawQuery:@"SELECT * FROM RawQueryTest"].rowCount == 1, @"RawQuery, row count was incorrect");
    
    XCTAssert([[[SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] valueForColumn:@"value" atRow:0] isEqualToString:@"testing123"], @"RawQuery, retrieved value is incorrect");
    
    XCTAssert(((NSNumber*)[[SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] valueForColumn:@"numValue" atRow:0]).intValue == 123, @"RawQuery, retrieved value is incorrect");
    
    XCTAssert([[[SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] valueForColumn:@"value" atRow:0] isKindOfClass:[NSString class]], @"RawQuery, class type is incorrect");
    
    XCTAssert([[[SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] valueForColumn:@"numValue" atRow:0] isKindOfClass:[NSNumber class]], @"RawQuery, class type is incorrect");
    
    XCTAssert([[[SharkORM rawQuery:@"SELECT * FROM RawQueryTest"] valueForColumn:@"blobValue" atRow:0] isKindOfClass:[NSNull class]], @"RawQuery, class type is incorrect");
    
}

- (void)test_raw_pragma {
    
    XCTAssert([[[SharkORM rawQuery:@"PRAGMA data_version;"] valueForColumn:@"data_version" atRow:0] isKindOfClass:[NSNumber class]], @"RawQuery, class type is incorrect");
    
    XCTAssert([SharkORM rawQuery:@"PRAGMA data_version;"].rowCount == 1, @"RawQuery, row count was incorrect");
    
    XCTAssert(((NSNumber*)[[SharkORM rawQuery:@"PRAGMA data_version;"] valueForColumn:@"data_version" atRow:0]).intValue == 2, @"RawQuery, retrieved value is incorrect");
    
}


@end
