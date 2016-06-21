//
//  Subclass.m
//  SharkORM
//
//  Created by Adrian Herridge on 21/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Subclass.h"

@implementation Subclass

- (void)test_check_subclass_swift_object {
    
    SmallPersonSwift* sp = [SmallPersonSwift new];
    sp.height = @(165);
    sp.Name = @"Adrian";
    [sp commit];
}

- (void)test_check_subclass_object {
    
    SmallPerson* sp = [SmallPerson new];
    sp.height = 165;
    sp.Name = @"Adrian";
    [sp commit];
}


@end
