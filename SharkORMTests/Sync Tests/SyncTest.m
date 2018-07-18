//
//  SyncTest.m
//  SharkORMTests
//
//  Created by Adrian Herridge on 18/07/2018.
//  Copyright © 2018 Adrian Herridge. All rights reserved.
//

#import "SyncTest.h"
#import "PersonSync.h"

@implementation SyncTest

- (void)test_sync_insert {
    
    NSString* testKey = [[[NSUUID UUID] UUIDString] lowercaseString];
    
    // clear all data from the tables
    [SharkORM setupTablesFromClasses:[PersonSync class]];
    
    // configure and startup the framework.
    SharkSync.Settings.applicationKey = @"f5b68ccc-297c-4417-9a63-52640bdb8748";
    SharkSync.Settings.accountKey = @"1eb245ef-f9a1-4183-b8f1-e4e1de658de0";
    SharkSync.Settings.aes256EncryptionKey = testKey;
    
    NSError* error = [SharkSync startService];
    if(error) {
        // an error occoured
        XCTAssert(error == nil, @"An error occoured starting the Sync service");
    }
    
    // create a record and commit it
    PersonSync* p = [PersonSync new];
    p.name = @"SharkSync.io Team";
    p.age = 36;
    [p commitInGroup:testKey];
    
    // delete the record
    [SharkORM rawQuery:@"DELETE FROM PersonSync;"];
    
    // check there is nothing in the table
    XCTAssert([[PersonSync query] count] == 0, @"Records found which should not be there");
    
    // add a visibility group
    [SharkSync addVisibilityGroup:testKey freqency:1];
    
    // sleep and wait for a sync event
    [NSThread sleepForTimeInterval:5];
    XCTAssert([[PersonSync query] count] == 1, @"Records not found which should be there");
    
}

@end
