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

#import "SRKCompoundIndex+Private.h"
#import "SharkORM.h"

@implementation SRKCompoundIndex

- (id)initWithProperties:(NSArray*) indexProperties {
    self = [super init];
    
    if (self != nil) {
        _indexProperties = indexProperties;
    }
    
    return self;
}

-(NSString*) getIndexName {
    NSString* indexName = @"idx_*tablename";
    for (SRKIndexProperty *indexProperty in [self indexProperties]) {
        indexName = [indexName stringByAppendingString:[NSString stringWithFormat:@"_%@_%@", indexProperty.name, [indexProperty getSortOrderIndexName]]];
    }
    return indexName;
}

-(NSString*) getPropertyString {
    NSString* propertyString = @"(";
    NSString* delim = @"";
    
    for (SRKIndexProperty *indexProperty in [self indexProperties]) {
        propertyString = [propertyString stringByAppendingString:[NSString stringWithFormat:@"%@%@ %@", delim, indexProperty.name,[indexProperty getSortOrderString]]];
        delim = @", ";
    }
    
    propertyString = [propertyString stringByAppendingString:@")"];
    
    return propertyString;
}


- (BOOL) isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    return [[self getIndexName] isEqual:[object getIndexName]];
}

-(NSUInteger)hash {
    NSUInteger result = 1;
    NSUInteger prime = 31;
    
    result = prime * result + [[self getIndexName] hash];
    
    return result;
}
@end
