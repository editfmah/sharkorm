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


#import "SchemaTests.h"

@implementation SchemaObject

@dynamic schemaField1,schemaField2;

+ (NSArray *)ignoredProperties {
    return @[@"schemaField2"];
}

@end

@implementation SchemaTests

- (void)test_ignored_properties {
    
    // reference the object to create the table
    SRKQuery* qry = [SchemaObject query];
    
    // now query the master database to check the ignored property is missing
    SRKRawResults* results = [SharkORM rawQuery:@"SELECT * FROM sqlite_master WHERE type='table' AND name='SchemaObject'"];
    XCTAssert([results rowCount] == 1, @"table schema was not created properly");
    
    results = [SharkORM rawQuery:@"SELECT * FROM sqlite_master WHERE type='table' AND name='SchemaObject' AND sql LIKE '%schemaField1%'"];
    XCTAssert([results rowCount] == 1, @"table schema was not created properly");
    
    results = [SharkORM rawQuery:@"SELECT * FROM sqlite_master WHERE type='table' AND name='SchemaObject' AND sql LIKE '%schemaField2%'"];
    XCTAssert([results rowCount] == 0, @"table schema was not created properly");
    
}

@end
