//
//  DBEncryptedObject.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRKEncryptedObject : NSObject

@property (strong) NSData* object;
@property (strong) NSNumber* obscurer;

- (BOOL)encryptObject:(id)object;
- (id)decryptObject;

@end
