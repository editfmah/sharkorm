//
//  SRKRawResults.m
//  SharkORM
//
//  Created by Adrian Herridge on 22/06/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import "SharkORM.h"

@implementation SRKRawResults

- (NSInteger)rowCount {
    if (self.rawResults) {
        return self.rawResults.count;
    }
    return 0;
}

- (NSInteger)columnCount {
    if (self.rawResults && self.rowCount) {
        NSDictionary* d = [self.rawResults objectAtIndex:0];
        if (d) {
            return d.allKeys.count;
        }
    }
    return 0;
}

- (id)valueForColumn:(NSString*)columnName atRow:(NSInteger)index {
    if (self.rawResults && self.rowCount && index < self.rowCount) {
        NSDictionary* d = [self.rawResults objectAtIndex:index];
        if (d) {
            return [d objectForKey:columnName];
        } else {
            // this, in theory is not possible
            return nil;
        }
    }
    return nil;
}

- (NSString*)columnNameForIndex:(NSInteger)index {
    if (self.rawResults && self.rowCount) {
        NSDictionary* d = [self.rawResults objectAtIndex:0];
        if (d) {
            return [d.allKeys objectAtIndex:index];
        }
    }
    return nil;
}

@end
