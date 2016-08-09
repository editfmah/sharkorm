//
//  OtherTests.m
//  SharkORM
//
//  Created by Adrian Herridge on 25/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "OtherTests.h"

@implementation OtherTests

- (void)test_print_concommited_object {
    Person* p = [Person new];
    [p commit];
    NSLog(@"%@",p);
}

- (void)test_print_unconcommited_object {
    Person* p = [Person new];
    NSLog(@"%@",p);
}

@end
