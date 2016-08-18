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
