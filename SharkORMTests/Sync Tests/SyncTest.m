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
    
//    [SharkORM rawQuery:@"DELETE FROM SharkSyncChange;"];
//    
//    for (NSString* grp in [SharkSync currentVisibilityGroups]) {
//        [SharkSync removeVisibilityGroup:grp];
//    }
//    
//    NSString* testKey = [[[NSUUID UUID] UUIDString] lowercaseString];
//    
//    // clear all data from the tables
//    [SharkORM setupTablesFromClasses:[PersonSync class]];
//    
//    // configure and startup the framework.
//    SharkSync.Settings.applicationKey = @"f5b68ccc-297c-4417-9a63-52640bdb8748";
//    SharkSync.Settings.accountKey = @"1eb245ef-f9a1-4183-b8f1-e4e1de658de0";
//    SharkSync.Settings.aes256EncryptionKey = testKey;
//    
//    NSError* error = [SharkSync startService];
//    if(error) {
//        // an error occoured
//        XCTAssert(error == nil, @"An error occoured starting the Sync service");
//    }
//    
//    // create a record and commit it
//    PersonSync* p = [PersonSync new];
//    p.name = @"SharkSync.io Team";
//    p.age = 36;
//    [p commitInGroup:testKey];
//    
//    // delete the record
//    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
//    
//    // check there is nothing in the table
//    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
//    
//    // add a visibility group
//    [SharkSync addVisibilityGroup:testKey freqency:1];
//    
//    // sleep and wait for a sync event
//    [NSThread sleepForTimeInterval:30];
//    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    
}

@end
