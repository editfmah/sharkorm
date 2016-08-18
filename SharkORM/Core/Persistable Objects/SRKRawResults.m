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
