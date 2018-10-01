//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
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

#import "SyncTest.h"
#import "PersonSync.h"

@implementation SyncTest

- (void)test_sync_insert {
    
    [SharkORM rawQuery:@"DELETE FROM SharkSyncChange;"];
    
    for (NSString* grp in [SharkSync currentVisibilityGroups]) {
        [SharkSync removeVisibilityGroup:grp];
    }
    
    NSString* testKey = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSString* testKey2 = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSString* testKey3 = [[[NSUUID UUID] UUIDString] lowercaseString];
    
    // clear all data from the tables
    [SharkORM setupTablesFromClasses:[PersonSync class]];
    
    // configure and startup the framework.
    SharkSync.Settings.applicationKey = @"f5b68ccc-297c-4417-9a63-52640bdb8748";
    SharkSync.Settings.accountKey = @"1eb245ef-f9a1-4183-b8f1-e4e1de658de0";
    SharkSync.Settings.aes256EncryptionKey = testKey;
    
    NSError* error = [SharkSync startService];
    [NSThread sleepForTimeInterval:30];
    if(error) {
        // an error occoured
        XCTAssert(error == nil, @"An error occoured starting the Sync service");
    }
    
    srand(@([NSDate date].timeIntervalSince1970).intValue);
    
    // create a record and commit it
    PersonSync* p = [PersonSync new];
    p.name = @"SharkSync.io Team";
    p.age = 36;
    p.seq = rand() % 10000000;
    p.payrollNumber = rand() % 1000000;
    [p commitInGroup:testKey];
    
    // delete the record
    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
    
    // check there is nothing in the table
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    // add a visibility group
    [SharkSync addVisibilityGroup:testKey freqency:1];
    
    // sleep and wait for a sync event
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    
    PersonSync* so = (PersonSync*)[[PersonSync query] first];
    XCTAssert([so.name isEqualToString:@"SharkSync.io Team"], @"synchronised value incorrect");
    XCTAssert(so.age = 36, @"synchronised value incorrect");
    
    // now test multi groups
    PersonSync* p2 = [PersonSync new];
    p2.name = @"SharkSync.io Team 2";
    p2.age = 38;
    p2.seq = rand() % 10000000;
    p2.payrollNumber = rand() % 1000000;
    [p2 commitInGroup:testKey2];
    
    PersonSync* p3 = [PersonSync new];
    p3.name = @"SharkSync.io Team 3";
    p3.age = 40;
    p3.seq = rand() % 10000000;
    p3.payrollNumber = rand() % 1000000;
    [p3 commitInGroup:testKey3];
    
    [SharkORM rawQuery:@"DELETE FROM PersonSync WHERE age > 36;"];
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    [NSThread sleepForTimeInterval:1];
    
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    [SharkSync addVisibilityGroup:testKey2 freqency:1];
    [SharkSync addVisibilityGroup:testKey3 freqency:1];
    
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 3, @"Records not found which should be there");
    
    // delete a group, should reduce the associated records
    [SharkSync removeVisibilityGroup:testKey3];
    XCTAssert([[PersonSync query] count] == 2, @"Records not found which should be there");
    
    [SharkSync removeVisibilityGroup:testKey2];
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    
    [SharkSync removeVisibilityGroup:testKey];
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    // change the enctyption key to something invalid
    SharkSync.Settings.aes256EncryptionKey = testKey2;
    [SharkSync addVisibilityGroup:testKey freqency:1];
    
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    
    so = (PersonSync*)[[PersonSync query] first];
    XCTAssert(![so.name isEqualToString:@"SharkSync.io Team"], @"synchronised value incorrect");
    XCTAssert(so.age != 36, @"synchronised value incorrect");
    
    // remove invalid record and group
    [SharkSync removeVisibilityGroup:testKey];
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    // now check record deletion
    SharkSync.Settings.aes256EncryptionKey = testKey;
    
    for (NSString* grp in [SharkSync currentVisibilityGroups]) {
        [SharkSync removeVisibilityGroup:grp];
    }
    
    // add all the groups in
    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
    
    [SharkSync addVisibilityGroup:testKey freqency:1];
    [SharkSync addVisibilityGroup:testKey2 freqency:1];
    [SharkSync addVisibilityGroup:testKey3 freqency:1];
    
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 3, @"Records not found which should be there");
    
    // now remove them
    [[[PersonSync query] fetch] remove];
    
    [NSThread sleepForTimeInterval:3];
    
    for (NSString* grp in [SharkSync currentVisibilityGroups]) {
        [SharkSync removeVisibilityGroup:grp];
    }
    // add all the groups in
    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
    
    [SharkSync addVisibilityGroup:testKey freqency:1];
    [SharkSync addVisibilityGroup:testKey2 freqency:1];
    [SharkSync addVisibilityGroup:testKey3 freqency:1];
    
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    // create a record in group 1
    PersonSync* p4 = [PersonSync new];
    p4.name = @"SharkSync.io Change Group Test";
    p4.age = 123;
    p4.seq = rand() % 10000000;
    p4.payrollNumber = rand() % 1000000;
    [p4 commitInGroup:testKey];
    
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 1, @"Records found which should not be there");
    
    [p4 commitInGroup:testKey2];
    [NSThread sleepForTimeInterval:3];
    
    for (NSString* grp in [SharkSync currentVisibilityGroups]) {
        [SharkSync removeVisibilityGroup:grp];
    }
    // add all the groups in
    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
    
    [SharkSync addVisibilityGroup:testKey freqency:1];
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    [SharkSync addVisibilityGroup:testKey2 freqency:1];
    [NSThread sleepForTimeInterval:3];
    XCTAssert([[PersonSync query] count] == 1, @"Records found which should not be there");
    
}

@end
