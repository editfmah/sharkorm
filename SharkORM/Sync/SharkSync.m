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

#import "SharkORM+Private.h"
#import "SRKEntity+Private.h"
#import "SRKDefunctObject.h"
#import "SRKSyncOptions.h"
#import <CommonCrypto/CommonCrypto.h>
#import "SRKAES256Extension.h"
#import "SRKSyncRegisteredClass.h"
#import "SharkSync+Private.h"


#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
typedef UIImage XXImage;
#else
typedef NSImage XXImage;
#endif


#if TARGET_OS_IPHONE
#else
#import <AppKit/AppKit.h>
#endif

@interface SharkSync ()

@end

@implementation SharkSync

+ (SharkSyncSettings *)Settings {
    return [SharkSync sharedObject].settings;
}

+ (NSError *)startService {
    
    SharkSyncSettings* current = [SharkSync Settings];
    if (current.applicationKey == nil) {
        return [NSError errorWithDomain:@"sharksync.io.error" code:1 userInfo:@{@"Missing" : @"Application key has not been specified"}];
    }
    if (current.accountKey == nil) {
        return [NSError errorWithDomain:@"sharksync.io.error" code:1 userInfo:@{@"Missing" : @"Account key has not been specified"}];
    }
    if (current.aes256EncryptionKey == nil) {
        return [NSError errorWithDomain:@"sharksync.io.error" code:1 userInfo:@{@"Missing" : @"No encryption key specified, unable to communicate with server."}];
    }
    [self startSynchronisation];
    return nil;
}

+ (void)startSynchronisation {
    [SyncService StartService];
}

+ (void)stopSynchronisation {
    [SyncService StopService];
}

+ (void)setChangeNotification:(SharkSyncChangesReceived)changeBlock {
    [SharkSync sharedObject].changeBlock = changeBlock;
}

+ (instancetype)sharedObject {
    
    static id this = nil;
    if (!this) {
        this = [SharkSync new];
        ((SharkSync*)this).concurrentRecordGroups = [NSMutableDictionary new];
        ((SharkSync*)this).settings = [SharkSyncSettings new];
        ((SharkSync*)this).currentGroups = [NSMutableArray arrayWithArray:[[SharkSyncGroup query] fetch]];
        if (((SharkSync*)this).currentGroups.count == 0) {
            [SharkSync addVisibilityGroup:SHARKSYNC_DEFAULT_GROUP freqency:((SharkSync*)this).settings.defaultPollInterval];
        }
        ((SharkSync*)this).countOfChangesToSyncUp = [[SharkSyncChange query] count];
    }
    return this;
    
}

+ (NSString *)MD5FromString:(NSString *)inVar {
    
    const char * pointer = [inVar UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(pointer, (CC_LONG)strlen(pointer), md5Buffer);
    
    NSMutableString *string = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [string appendFormat:@"%02x",md5Buffer[i]];
    
    return string;
    
}

+ (void)addVisibilityGroup:(NSString *)visibilityGroup freqency:(int)frequency {
    
    // adds a visibility group to the table, to be sent with all sync requests.
    // AH originally wanted the groups to be set per class, but i think it's better that a visibility group be across all classes, much good idea for the dev
     @synchronized([SharkSync sharedObject].currentGroups) {
    BOOL found = NO;
    for (SharkSyncGroup* group in [SharkSync sharedObject].currentGroups) {
        if ([group.name isEqualToString:visibilityGroup]) {
            group.frequency = frequency*1000;
            [group commit];
        }
    }
    if (!found) {
        SharkSyncGroup* newGroup = [SharkSyncGroup new];
        newGroup.name = visibilityGroup;
        newGroup.tidemark = 0;
        newGroup.frequency = frequency * 1000;
        [newGroup commit];
        [[[SharkSync sharedObject] currentGroups] addObject:newGroup];
    }
     }
    
}

+ (NSArray<NSString *> *)currentVisibilityGroups {
    
     @synchronized([SharkSync sharedObject].currentGroups) {
    return [[SharkSyncGroup query] distinct:@"name"];
     }
}

+ (void)removeVisibilityGroup:(NSString *)visibilityGroup {
    
    if ([visibilityGroup isEqualToString:SHARKSYNC_DEFAULT_GROUP]) {
        return;
    }
    
     @synchronized([SharkSync sharedObject].currentGroups) {
    
    NSString* vg = visibilityGroup;
    
    [[[[[SharkSyncGroup query] where:@"name = ?" parameters:@[vg]]  limit:1] fetch] remove];
    
    // now we need to remove all the records which were part of this visibility group
    for (SRKSyncRegisteredClass* c in [[SRKSyncRegisteredClass query] fetch]) {
        NSString* sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE recordVisibilityGroup = '%@'", c.className, vg];
        // TODO: execute against all attached databases
        [SharkORM executeSQL:sql inDatabase:nil];
    }
    
    for (SharkSyncGroup* grp in [SharkSync sharedObject].currentGroups.copy) {
        if ([grp.name isEqualToString:visibilityGroup]) {
            [[[SharkSync sharedObject] currentGroups] removeObject:grp];
            break;
        }
    }
     }
}

+ (void)addChangesWritten:(uint64_t)changes {
    @synchronized([SharkSync sharedObject].currentGroups) {
        [SharkSync sharedObject].countOfChangesToSyncUp += changes;
    }
}

+ (NSString*)getEffectiveRecordGroup {
    @synchronized ([SharkSync sharedObject].concurrentRecordGroups) {
        return [[SharkSync sharedObject].concurrentRecordGroups objectForKey:[NSString stringWithFormat:@"%@", [NSThread currentThread]]];
    }
}

+ (void)setEffectiveRecorGroup:(NSString*)group {
    [[SharkSync sharedObject].concurrentRecordGroups setObject:group forKey:[NSString stringWithFormat:@"%@", [NSThread currentThread]]];
}

+ (void)clearEffectiveRecordGroup {
    [[SharkSync sharedObject].concurrentRecordGroups removeObjectForKey:[NSString stringWithFormat:@"%@", [NSThread currentThread]]];
}

+ (id)decryptValue:(NSString*)value {
    
    if (!value) {
        return nil;
    }
    
    NSData* dValue = [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    // call the block in the sync settings to encrypt the data
    SharkSync* sync = [SharkSync sharedObject];
    SharkSyncSettings* settings = sync.settings;
    
    // get the first byte and check which style of encryption is being used
    uint8_t type = 0;
    [dValue getBytes:&type length:1];
    NSData* encryptedData = [dValue subdataWithRange:NSMakeRange(1, dValue.length-1)];
    NSData* decrypteddata = nil;
    
    if (type == SharkSyncEncryptionTypeAES256v1) {
        
        decrypteddata = [SharkSync SRKAES256DecryptWithKey:settings.aes256EncryptionKey data:encryptedData];
        if (!decrypteddata) {
            return nil;
        }
        
    } else if (type == SharkSyncEncryptionTypeUser) {
        if (settings.decryptBlock) {
            // this is a custom encryption
            decrypteddata = settings.decryptBlock(encryptedData);
            if (!decrypteddata) {
                return nil;
            }
        } else {
            return nil;
        }
    }
    
    if (decrypteddata.length < 2) {
        return nil;
    }
    
    uint8_t dataType = 0;
    [decrypteddata getBytes:&dataType length:1];
    decrypteddata = [decrypteddata subdataWithRange:NSMakeRange(2, decrypteddata.length-2)];
    
    if (dataType == SharkSyncPropertyTypeText) {
        
        return [[NSString alloc] initWithData:decrypteddata encoding:NSUnicodeStringEncoding];
        
    } else if (dataType == SharkSyncPropertyTypeNumber) {
        
        double d = 0;
        [decrypteddata getBytes:&d length:sizeof(double)];
        return @(d);
        
    } else if (dataType == SharkSyncPropertyTypeImage) {
        
#if TARGET_OS_IPHONE
       return [UIImage imageWithData:decrypteddata];
#else
       return [[NSImage alloc] initWithData:decrypteddata];
#endif
        
        
        
    } else if (dataType == SharkSyncPropertyTypeDate) {
        
        double d = 0;
        [decrypteddata getBytes:&d length:sizeof(double)];
        return [NSDate dateWithTimeIntervalSince1970:d];
        
    } else if (dataType == SharkSyncPropertyTypeArray || dataType == SharkSyncPropertyTypeMutableArray || dataType == SharkSyncPropertyTypeDictionary || dataType == SharkSyncPropertyTypeMutableDictionary) {
        
        id object = [NSJSONSerialization JSONObjectWithData:decrypteddata options:NSJSONReadingMutableLeaves error:nil];
        if (!object) {
            return nil;
        }
        if (dataType == SharkSyncPropertyTypeArray) {
            return [NSArray arrayWithArray:object];
        } else if (dataType == SharkSyncPropertyTypeMutableArray) {
            return [NSMutableArray arrayWithArray:object];
        } else if (dataType == SharkSyncPropertyTypeDictionary) {
            return [NSDictionary dictionaryWithDictionary:object];
        } else if (dataType == SharkSyncPropertyTypeMutableDictionary) {
            return [NSMutableDictionary dictionaryWithDictionary:object];
        }
        
    } else if (dataType == SharkSyncPropertyTypeNull) {
        
        return [NSNull new];
        
    } else if (dataType == SharkSyncPropertyTypeEntityString) {
        
        return [[NSString alloc] initWithData:decrypteddata encoding:NSUnicodeStringEncoding];
        
    } else if (dataType == SharkSyncPropertyTypeEntityNumeric) {
        
        double d = 0;
        [decrypteddata getBytes:&d length:sizeof(double)];
        return @(d);
        
    }
    
    return nil;
    
}

+ (void)queueObject:(SRKSyncObject *)object withChanges:(NSMutableDictionary*)changes withOperation:(SharkSyncOperation)operation inHashedGroup:(NSString*)group {
    
    if (![[[SRKSyncRegisteredClass query] where:@"className = ?" parameters:@[[object.class description]]] count]) {
        SRKSyncRegisteredClass* c = [SRKSyncRegisteredClass new];
        c.className = [object.class description];
        [c commit];
    }
    
    if (operation == SharkSyncOperationCreate || operation == SharkSyncOperationSet) {
        
        /* we have an object so look at the modified fields and queue the properties that have been set */
        for (NSString* property in changes.allKeys) {
            
            // exclude the group and ID keys
            if (![property isEqualToString:@"Id"] && ![property isEqualToString:@"recordVisibilityGroup"]) {
                
                /* because all values are encrypted by the client before being sent to the server, we need to convert them into NSData,
                 to be encrypted however the developer wants, using any method */
                
                id value = [changes objectForKey:property];
                SharkSyncPropertyType type = SharkSyncPropertyTypeNull;
                NSMutableData* dValue = [NSMutableData new];
                
                // insert a random byte into the value to mix up the encryption
                srand(@([NSDate date].timeIntervalSince1970).intValue);
                
                if (value) {
                    
                    if ([value isKindOfClass:[NSString class]]) {
                        type = SharkSyncPropertyTypeText;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                        [dValue appendData:[((NSString*)value) dataUsingEncoding: NSUnicodeStringEncoding allowLossyConversion:NO]];
                    }
                    else if ([value isKindOfClass:[NSNumber class]]) {
                        type = SharkSyncPropertyTypeNumber;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                        double v = ((NSNumber*)value).doubleValue;
                        [dValue appendBytes:&v length:sizeof(double)];
                    }
                    else if ([value isKindOfClass:[NSDate class]]) {
                        type = SharkSyncPropertyTypeDate;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                        double v = ((NSDate*)value).timeIntervalSince1970;
                        [dValue appendBytes:&v length:sizeof(double)];
                    }
                    else if ([value isKindOfClass:[NSData class]]) {
                        type = SharkSyncPropertyTypeBytes;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                        [dValue appendData:((NSData*)value)];
                    }
                    else if ([value isKindOfClass:[XXImage class]]) {
                        type = SharkSyncPropertyTypeImage;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
#if TARGET_OS_IPHONE
                        [dValue appendData:UIImageJPEGRepresentation(((UIImage*)value), 0.7)];
#else
                        NSData *imageData = [((XXImage*)value) TIFFRepresentation];
                        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
                        NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:NSImageCompressionFactor];
                        imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
                        [dValue appendData:imageData];
#endif
                        
                    }
                    else if ([value isKindOfClass:[NSNull class]]) {
                        type = SharkSyncPropertyTypeNull;
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                    }
                    else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]]) {
                        
                        if ([value isKindOfClass:[NSMutableDictionary class]]) {
                            type = SharkSyncPropertyTypeMutableDictionary;
                        } else if ([value isKindOfClass:[NSMutableArray class]]) {
                            type = SharkSyncPropertyTypeMutableArray;
                        } else if ([value isKindOfClass:[NSDictionary class]]) {
                            type = SharkSyncPropertyTypeDictionary;
                        } else if ([value isKindOfClass:[NSArray class]]) {
                            type = SharkSyncPropertyTypeArray;
                        }
                        
                        [dValue appendBytes:&type length:sizeof(uint8_t)];
                        uint8_t r = (char)rand()%256;
                        [dValue appendBytes:&r length:sizeof(uint8_t)];
                        
                        NSError* error;
                        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                        if (jsonData) {
                            [dValue appendData:jsonData];
                        }
                        
                    } else if ([value isKindOfClass:[SRKEntity class]]) {
                        
                       id pk = ((SRKObject*)value).Id;
                        if ([pk isKindOfClass:[NSString class]]) {
                            type = SharkSyncPropertyTypeEntityString;
                            [dValue appendBytes:&type length:sizeof(uint8_t)];
                            uint8_t r = (char)rand()%256;
                            [dValue appendBytes:&r length:sizeof(uint8_t)];
                            [dValue appendData:[((NSString*)pk) dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion:NO]];
                        } else if ([pk isKindOfClass:[NSNumber class]]) {
                            type = SharkSyncPropertyTypeEntityNumeric;
                            [dValue appendBytes:&type length:sizeof(uint8_t)];
                            uint8_t r = (char)rand()%256;
                            [dValue appendBytes:&r length:sizeof(uint8_t)];
                            u_int64_t v = ((NSNumber*)value).unsignedLongLongValue;
                            [dValue appendBytes:&v length:sizeof(u_int64_t)];
                        }
                        
                    }
                    
                    // now encrypt and package the data
                    // call the block in the sync settings to encrypt the data
                    SharkSync* sync = [SharkSync sharedObject];
                    SharkSyncSettings* settings = sync.settings;
                    
                    NSData* encryptedData = nil;
                    SharkSyncEncryptionType encryptType = SharkSyncEncryptionTypeAES256v1;
                    if (settings.encryptBlock) {
                        
                        encryptType = SharkSyncEncryptionTypeUser;
                        encryptedData = settings.encryptBlock(dValue);
                        
                    } else {
                        
                        encryptedData = [SharkSync SRKAES256EncryptWithKey:settings.aes256EncryptionKey data:dValue];
                        
                    }
                    
                    dValue = [NSMutableData new];
                    [dValue appendBytes:&type length:sizeof(SharkSyncEncryptionType)];
                    [dValue appendData:encryptedData];
                    
                    SharkSyncChange* change = [SharkSyncChange new];
                    change.recordId = object.Id;
                    change.entity = [[object class] description];
                    change.property = property;
                    change.action = operation;
                    change.recordGroup = group;
                    change.timestamp = [[NSDate date] timeIntervalSince1970];
                    change.value = [dValue base64EncodedStringWithOptions:0];
                    [change commit];
                    
                }

            }
            
        }
    } else if (operation == SharkSyncOperationDelete) {
        
        SharkSyncChange* change = [SharkSyncChange new];
        change.entity = [[object class] description];
        change.property = @"__delete__";
        change.recordId = object.Id;
        change.action = operation;
        change.recordGroup = group;
        change.timestamp = [[NSDate date] timeIntervalSince1970];
        [change commit];
        
    }
    
}

+ (NSData *)SRKAES256EncryptWithKey:(NSString *)key data:(NSData*)data {
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [data bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
    
}

+ (NSData *)SRKAES256DecryptWithKey:(NSString *)key data:(NSData*)data {
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [data bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
    
}

@end

#import <CommonCrypto/CommonCrypto.h>

@implementation SharkSyncSettings

- (instancetype)init {
    self = [super init];
    if (self) {
        
        // these are just defaults to ensure all data is encrypted, it is reccommended that you develop your own or at least set your own aes256EncryptionKey value.
        
        self.autoSubscribeToGroupsWhenCommiting = YES;
        self.aes256EncryptionKey = nil;
        self.encryptBlock = nil;
        self.decryptBlock = nil;
        self.defaultPollInterval = 60;
        self.serviceUrl = @"https://api.testingallthethings.net/Api/Sync";
        
    }
    return self;
}

@end
