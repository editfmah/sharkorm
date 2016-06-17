//
//  Examples.m
//  SharkORM
//
//  Created by Adrian Herridge on 17/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "Examples.h"

@implementation Examples

- (void)test_basic_example_methods {
    
    /* clear all pre-existing data from the entity class */
    [[[Person query] fetchLightweight] removeAll];
    
    /* now create a new object ready for persistence */
    Person* newPerson = [Person new];
    
    // set some values
    newPerson.Name = @"Adrian";
    newPerson.age = 38;
    newPerson.payrollNumber = 12345678;
    
    [newPerson commit];
    
    /* getting objects back again */
    
    SRKResultSet* results = [[Person query] fetch];
    for (Person* p in results) {
        
        // modify the record and then commit the change back in again
        p.age +=1;
        [p commit];
        
    }
    
}

@end
