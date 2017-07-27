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



#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SRKIndexDefinition+Private.h"
#import "SharkORM+Private.h"
#import "SRKCompoundIndex+Private.h"

@implementation SRKIndexDefinition

- (void)addIndexWithProperties: (SRKIndexProperty *)indexProperty, ... NS_REQUIRES_NIL_TERMINATION {
    if (!_components) {
        _components = [NSMutableArray new];
    }
    
    NSMutableArray *properties = [[NSMutableArray alloc] init];
    SRKIndexProperty *eachProperty;
    va_list argumentList;
    if (indexProperty) {
        [properties addObject:indexProperty];
        va_start(argumentList, indexProperty);
        while ((eachProperty = va_arg(argumentList, SRKIndexProperty*)) != nil) {
            [properties addObject:eachProperty];
        }
        va_end(argumentList);
    }
    
    
    SRKCompoundIndex *index = [[SRKCompoundIndex alloc] initWithProperties:properties];
    
    /* check for a duplicate */
    BOOL found = NO;
    for (SRKCompoundIndex* compoundIndex in _components) {
        if ([compoundIndex isEqual:index]) {
            found = YES;
        }
    }
    if (!found) {
        [_components addObject:index];
    }
}

- (void)addIndexForProperty:(NSString *)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder {
    
    SRKIndexProperty * property = [[SRKIndexProperty alloc] initWithName:propertyName andOrder:propOrder];
    
    [self addIndexWithProperties:property, nil];
    
}

- (void)addIndexForProperty:(NSString *)propertyName propertyOrder:(enum SRKIndexSortOrder)propOrder secondaryProperty:(NSString *)secProperty secondaryOrder:(enum SRKIndexSortOrder)secOrder {
    SRKIndexProperty * property = [[SRKIndexProperty alloc] initWithName:propertyName andOrder:propOrder];
    SRKIndexProperty * secondProperty = [[SRKIndexProperty alloc] initWithName:secProperty andOrder:secOrder];
    
    [self addIndexWithProperties:property, secondProperty, nil];

}

- (void)generateIndexesForTable:(NSString*)tableName inDatabase:(NSString *)dbName{
	for (SRKCompoundIndex* index in _components) {
        NSString* execSql = [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ %@;", [index getIndexName], tableName, [index getPropertyString]];
        execSql = [execSql stringByReplacingOccurrencesOfString:@"*tablename" withString:tableName];
        [SharkORM executeSQL:execSql inDatabase:dbName];
	}
}

@end
