//
//  DBEncryptedObject.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKEncryptedObject.h"
#import "SharkORM+Private.h"
#import <CommonCrypto/CommonCrypto.h>

@interface NSData (SharkORMEncryption)
- (NSData *)SRKAES256EncryptWithKey:(NSString *)key;
- (NSData *)SRKAES256DecryptWithKey:(NSString *)key;
@end

@implementation NSData (SharkORMEncryption)
- (NSData *)SRKAES256EncryptWithKey:(NSString *)key {
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesEncrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [self bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesEncrypted);
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}

- (NSData *)SRKAES256DecryptWithKey:(NSString *)key {
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesDecrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [self bytes], dataLength, /* input */
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

@implementation SRKEncryptedObject

-(void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.object forKey:@"object"];
	[aCoder encodeObject:self.obscurer forKey:@"obscurer"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super init])) {
		self.object = [aDecoder decodeObjectForKey:@"object"];
		self.obscurer = [aDecoder decodeObjectForKey:@"obscurer"];
	}
	return self;
}

- (BOOL)encryptObject:(id)object {
	
	BOOL success = NO;
	
	@try {
		NSMutableData *data = [[NSMutableData alloc]init];
		NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
		[archiver encodeObject:object];
		[archiver finishEncoding];
		if (data) {
			self.object = [data SRKAES256EncryptWithKey:[SharkORM getSettings].encryptionKey];
			success = YES;
		}
	}
	@catch (NSException *exception) {
		/* object could not be encrypted */
		self.object = nil;
	}
	@finally {
		
	}
	
	return success;
	
}

-(id)decryptObject {
	
	if (self.object) {
		
		NSData* unEncData = [self.object SRKAES256DecryptWithKey:[SharkORM getSettings].encryptionKey];
		
		NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:unEncData];
		id o = [unarchiver decodeObject];
		[unarchiver finishDecoding];
		
		return o;
		
	}
	
	return nil;
	
}

@end
