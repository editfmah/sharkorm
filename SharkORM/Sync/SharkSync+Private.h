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



#ifndef SharkSync_Private_h
#define SharkSync_Private_h

#import "SharkORM.h"
#import "SharkSyncGroup.h"
#import "SharkSyncChange.h"
#import "SRKSyncObject+Private.h"
#import "SRKEntity+Private.h"
#import "SharkORM+Private.h"
#import "SRKDefunctObject.h"
#import "SRKDeferredChange.h"
#import "SyncService.h"
#import "SyncRequest.h"


typedef enum : uint8_t {
    
    SharkSyncEncryptionTypeAES256v1 = 0x01,
    SharkSyncEncryptionTypeUser = 0xFF,
    
} SharkSyncEncryptionType;

typedef enum : NSUInteger {
    SharkSyncOperationCreate = 1,     // a new object has been created
    SharkSyncOperationSet = 2,        // a value(s) have been set
    SharkSyncOperationDelete = 3,     // object has been removed from the store
    SharkSyncOperationIncrement = 4,  // value has been incremented - future implementation
    SharkSyncOperationDecrement = 5,  // value has been decremented - future implementation
} SharkSyncOperation;

@interface SharkSync ()

@property (strong, nullable) NSMutableDictionary* concurrentRecordGroups;
@property (strong, nonnull) SharkSyncSettings* settings;
@property (copy) SharkSyncChangesReceived _Nullable changeBlock;

// maintained to save querying the database
@property (strong) NSMutableArray<SharkSyncGroup*>* _Nullable currentGroups;
@property (strong) id __nonnull countLock;

+ (nullable id)decryptValue:(nonnull NSString*)value property:(nonnull NSString*)property entity:(nonnull NSString*)entity;
+ (void)queueObject:(nonnull SRKEntity *)object withChanges:(nullable NSMutableDictionary*)changes withOperation:(SharkSyncOperation)operation inHashedGroup:(nonnull NSString*)group;
+ (nonnull instancetype)sharedObject;

+ (nullable NSString *)SRKAES256EncryptWithKey:(nonnull NSString *)key data:(nonnull NSString*)data;
+ (nullable NSString *)SRKAES256DecryptWithKey:(nonnull NSString *)key data:(nonnull NSString*)data;

@end

@interface SRKSyncObject ()

- (BOOL)__commitRawWithObjectChain:(nonnull SRKEntityChain *)chain group:(nullable NSString*)group;

@end

#endif /* SharkSync_Private_h */
