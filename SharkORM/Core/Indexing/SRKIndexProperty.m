//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
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

@implementation SRKIndexProperty

-(id) initWithName:(NSString *)columnName {
    return [self initWithName:columnName andOrder:SRKIndexSortOrderAscending];
}

-(id) initWithName:(NSString*)columnName andOrder:(enum SRKIndexSortOrder) sortOrder {
    self =  [super init];
    
    if (self != nil) {
        _name = columnName;
        _order = sortOrder;
    }
    return self;
}

-(NSString*) getSortOrderString {
    if (_order == SRKIndexSortOrderAscending) {
        return @"asc";
    } else if (_order == SRKIndexSortOrderDescending) {
        return @"desc";
    } else if (_order == SRKIndexSortOrderNoCase) {
        return @"collate nocase";
    }
    return nil;
}

-(NSString*) getSortOrderIndexName {
    if (_order == SRKIndexSortOrderAscending) {
        return @"asc";
    } else if (_order == SRKIndexSortOrderDescending) {
        return @"desc";
    } else if (_order == SRKIndexSortOrderNoCase) {
        /* This is named for backwards compatibility reasons, fixing the bug now will cause people to create an additional index within their database that does the same thing */
        return @"desc";
    }
    return nil;
}

@end
