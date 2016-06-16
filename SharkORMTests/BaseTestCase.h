//
//  BaseTestCase.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef BaseTestCase_h
#define BaseTestCase_h

#import <XCTest/XCTest.h>
#import "Tests.h"

@interface BaseTestCase : XCTestCase <SRKDelegate>

@property (strong) SRKError* currentError;

- (void)cleardown;

@end

#endif /* BaseTestCase_h */
