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

@interface SRKGlobals : NSObject

+ (instancetype)sharedObject;

// sqlite3 handles
- (int)countOfHandles;
- (void*)defaultHandle;
- (NSString*)defaultDatabaseName;
- (void*)handleForIndex:(int)index;
- (void*)handleForName:(NSString*)key;
- (void)removeHandleForName:(NSString*)key;
- (void)addHandle:(void*)handle forDBName:(NSString*)dbHandle;

// delegate object
- (void)setDelegate:(id<SRKDelegate>)delegate;
- (id<SRKDelegate>)delegate;

// settings
- (SRKSettings*)settings;

// locks
- (id)writeLockObject;

// schema
- (NSMutableDictionary*)tableSchemas;
- (NSMutableDictionary*)primaryKeys;
- (NSMutableDictionary*)primaryTypes;

// relationships
- (NSMutableArray*)systemEntityRelationships;
- (NSArray*)systemEntityRelationshipsReadOnly;

// global event callbacks
- (void)setInsertCallback:(SRKGlobalEventCallback)callback;
- (void)setUpdateCallback:(SRKGlobalEventCallback)callback;
- (void)setDeleteCallback:(SRKGlobalEventCallback)callback;
- (SRKGlobalEventCallback)getInsertCallback;
- (SRKGlobalEventCallback)getUpdateCallback;
- (SRKGlobalEventCallback)getDeleteCallback;

// schema information
- (void)setFQNameForClass:(NSString*)shortName fullName:(NSString*)fullName;
- (NSString*)getFQNameForClass:(NSString*)shortName;



@end
