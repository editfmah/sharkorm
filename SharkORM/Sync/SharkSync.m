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

+ (id)decryptValue:(NSString*)value property:(NSString*)property entity:(NSString*)entity {
    
    if (!value) {
        return nil;
    }
    
    NSString* encryptedData = [[NSString alloc] initWithData:[[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters] encoding:NSNonLossyASCIIStringEncoding];
    
    // call the block in the sync settings to encrypt the data
    SharkSync* sync = [SharkSync sharedObject];
    SharkSyncSettings* settings = sync.settings;
    
    // get the first byte and check which style of encryption is being used
    NSString* decrypteddata = nil;
    
    if (settings.decryptBlock) {
        // this is a custom encryption
        decrypteddata = settings.decryptBlock(encryptedData);
        if (!decrypteddata) {
            return nil;
        }
    } else {
        decrypteddata = [SharkSync SRKAES256DecryptWithKey:SharkSync.Settings.aes256EncryptionKey data:encryptedData];
        if (!decrypteddata) {
            return nil;
        }
    }
    
    int dataType = [[SharkSchemaManager shared] schemaPropertyType:entity property:property];
    
    if (dataType == SRK_PROPERTY_TYPE_STRING) {
        
        return decrypteddata;
        
    } else if (dataType == SRK_PROPERTY_TYPE_NUMBER) {
        
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterNoStyle;
        return [f numberFromString:decrypteddata];
        
    } else if (dataType == SRK_PROPERTY_TYPE_IMAGE) {
        
#if TARGET_OS_IPHONE
        return [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:decrypteddata options:NSDataBase64DecodingIgnoreUnknownCharacters]];
#else
        return [[NSImage alloc] initWithData:[[NSData alloc] initWithBase64EncodedString:decrypteddata options:NSDataBase64DecodingIgnoreUnknownCharacters]];
#endif
        
    } else if (dataType == SRK_PROPERTY_TYPE_DATE) {
        
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterNoStyle;
        NSNumber* n = [f numberFromString:decrypteddata];
        if (!n) {
            return  nil;
        }
        
        return [NSDate dateWithTimeIntervalSince1970:n.doubleValue / 1000];
        
    } else if (dataType == SRK_PROPERTY_TYPE_ARRAY || dataType == SRK_PROPERTY_TYPE_MUTABLEARAY || dataType == SRK_PROPERTY_TYPE_DICTIONARY || dataType == SRK_PROPERTY_TYPE_MUTABLEDIC) {
        
        id object = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:decrypteddata.UTF8String length:decrypteddata.length] options:NSJSONReadingMutableLeaves error:nil];
        if (!object) {
            return nil;
        }
        if (dataType == SRK_PROPERTY_TYPE_ARRAY) {
            return [NSArray arrayWithArray:object];
        } else if (dataType == SRK_PROPERTY_TYPE_MUTABLEARAY) {
            return [NSMutableArray arrayWithArray:object];
        } else if (dataType == SRK_PROPERTY_TYPE_DICTIONARY) {
            return [NSDictionary dictionaryWithDictionary:object];
        } else if (dataType == SRK_PROPERTY_TYPE_MUTABLEDIC) {
            return [NSMutableDictionary dictionaryWithDictionary:object];
        }
        
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
                NSString* dValue = nil;
                
                if (value) {
                    
                    if ([value isKindOfClass:[NSString class]]) {
                        dValue = value;
                    }
                    else if ([value isKindOfClass:[NSNumber class]]) {
                        dValue = [NSString stringWithFormat:@"%@", value];
                    }
                    else if ([value isKindOfClass:[NSDate class]]) {
                        dValue = [NSString stringWithFormat:@"%@", @(@(((NSDate*)value).timeIntervalSince1970 * 1000).longLongValue)];
                    }
                    else if ([value isKindOfClass:[NSData class]]) {
                        dValue = [((NSData*)value) base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                    }
                    else if ([value isKindOfClass:[XXImage class]]) {
                        
                        NSMutableData* data;
                        
#if TARGET_OS_IPHONE
                        data = [NSMutableData dataWithData:UIImageJPEGRepresentation(((UIImage*)value), 0.7)];
#else
                        NSData *imageData = [((XXImage*)value) TIFFRepresentation];
                        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
                        NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:NSImageCompressionFactor];
                        imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
                        data = [NSMutableData dataWithData:imageData];
#endif
                        
                        if (data) {
                            dValue = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                        }
                        
                        
                    }
                    else if ([value isKindOfClass:[NSNull class]]) {
                        dValue = nil;
                    }
                    else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]]) {
                        
                        NSError* error;
                        NSString* jsonData = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error] encoding:NSNonLossyASCIIStringEncoding];
                        if (jsonData) {
                            dValue = jsonData;
                        }
                        
                    } else if ([value isKindOfClass:[SRKEntity class]]) {
                        
                        id pk = ((SRKObject*)value).Id;
                        if ([pk isKindOfClass:[NSString class]]) {

                            dValue = (NSString*)pk;
                            
                        } else if ([pk isKindOfClass:[NSNumber class]]) {
                            
                            dValue = [NSString stringWithFormat:@"%@", value];
                            
                        }
                        
                    }
                    
                    // now encrypt and package the data
                    // call the block in the sync settings to encrypt the data
                    SharkSync* sync = [SharkSync sharedObject];
                    SharkSyncSettings* settings = sync.settings;
                    
                    NSString* encryptedData = nil;
                    SharkSyncEncryptionType encryptType = SharkSyncEncryptionTypeAES256v1;
                    if (settings.encryptBlock) {
                        
                        encryptType = SharkSyncEncryptionTypeUser;
                        encryptedData = settings.encryptBlock(dValue);
                        
                    } else {
                        
                        encryptedData = [SharkSync SRKAES256EncryptWithKey:SharkSync.Settings.aes256EncryptionKey data:dValue];
                        
                    }
                    
                    dValue = encryptedData;
                    
                    SharkSyncChange* change = [SharkSyncChange new];
                    change.recordId = object.Id;
                    change.entity = [[object class] description];
                    change.property = property;
                    change.action = operation;
                    change.recordGroup = group;
                    change.timestamp = [[NSDate date] timeIntervalSince1970];
                    change.value = dValue;
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

+ (NSString *)SRKAES256EncryptWithKey:(NSString *)key data:(NSString*)stringData {
    
    NSData* data = [NSData dataWithBytes:stringData.UTF8String length:stringData.length];
    
    char keyData[key.length+64];
    bzero(keyData, sizeof(keyData));
    memcpy(&keyData, key.UTF8String, key.length);
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    memcpy(&keyPtr, keyData, sizeof(keyPtr));
    
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
        return [[NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    }
    
    free(buffer); //free the buffer;
    return nil;
    
}

+ (NSString *)SRKAES256DecryptWithKey:(NSString *)key data:(NSString*)stringData {
    
    NSData* data = [[NSData alloc] initWithBase64EncodedData:[NSData dataWithBytes:stringData.UTF8String length:stringData.length] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    char keyData[key.length+64];
    bzero(keyData, sizeof(keyData));
    memcpy(&keyData, key.UTF8String, key.length);
    
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    memcpy(&keyPtr, keyData, sizeof(keyPtr));
    
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
        return [NSString stringWithUTF8String:[NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted].bytes];
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
        self.defaultPostValues = [NSMutableDictionary new];
        
    }
    return self;
}

@end
