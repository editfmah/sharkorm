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
    self.currentError = nil;
    
}

- (void)tearDown {
    
    [[[Person query] fetch] removeAll];
    
    [SharkORM closeDatabaseNamed:@"Persistence"];
    [SharkORM setDelegate:nil];
    self.currentError = nil;
    [super tearDown];
}

- (void)cleardown {
    [[[Person query] fetchLightweight] removeAll];
    [[[PersonSwift query] fetchLightweight] removeAll];
    [[[Department query] fetchLightweight] removeAll];
    [[[DepartmentSwift query] fetchLightweight] removeAll];
    [[[Location query] fetchLightweight] removeAll];
    [[[SmallPerson query] fetchLightweight] removeAll];
    [[[SmallPersonSwift query] fetchLightweight] removeAll];
}

- (void)databaseError:(SRKError *)error {
    NSLog(@"error = %@\nsql=%@", error.errorMessage, error.sqlQuery);
}

@end