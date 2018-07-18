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


#import "Examples.h"

@implementation Examples

- (void)test_basic_example_methods {
    
    /* clear all pre-existing data from the entity class */
    [[[Person query] fetchLightweight] remove];
    
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
