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

#import "SRKSyncNodesList.h"

@implementation SRKSyncNodesList

- (instancetype)init {
    self = [super init];
    if (self) {
        self.nodes = [NSMutableArray new];
    }
    return self;
}

- (void)addNodeWithAddress:(NSString *)pathAndPort priority:(int)priority {
    
    // simples way to add more random chance of the node being picked for the weighting
    for (int i=0; i < priority; i++) {
        [self.nodes addObject:pathAndPort];
    }
    
}

- (NSString *)pickNode {
    
    srand([[NSDate date] timeIntervalSince1970]);
    int index = rand() % (_nodes.count);
    return [_nodes objectAtIndex:index];
    
}

@end
