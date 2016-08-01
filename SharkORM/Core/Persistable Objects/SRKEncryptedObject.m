//
//  DBEncryptedObject.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SRKEncryptedObject.h"
#import "SharkORM+Private.h"
#import "SRKAES256Extension.h"

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
