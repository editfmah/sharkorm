//
//  SharkORMTests.m
//  SharkORMTests
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "BaseTestCase.h"

@implementation BaseTestCase

- (void)setUp {
    [super setUp];

    [SharkORM setDelegate:self];
    [SharkORM openDatabaseNamed:@"Persistence"];
    [SharkORM rawQuery:@"DROP TABLE IF EXISTS RawQueryTest;"];
    self.currentError = nil;
    
}

- (void)tearDown {
    
    [self cleardown];
    
    [SharkORM closeDatabaseNamed:@"Persistence"];
    [SharkORM setDelegate:nil];
    self.currentError = nil;
    [super tearDown];
}

- (void)cleardown {
    [SharkORM rawQuery:@"DELETE FROM Person;"];
    [SharkORM rawQuery:@"DELETE FROM Department;"];
    [SharkORM rawQuery:@"DELETE FROM Location;"];
    [SharkORM rawQuery:@"DELETE FROM SmallPerson;"];
    [SharkORM rawQuery:@"DELETE FROM StringIdObject;"];
    [SharkORM rawQuery:@"DELETE FROM MostObjectTypes;"];
}

- (void)databaseError:(SRKError *)error {
    NSLog(@"error = %@\nsql=%@", error.errorMessage, error.sqlQuery);
}

@end
