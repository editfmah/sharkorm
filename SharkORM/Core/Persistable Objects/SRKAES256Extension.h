//
//  SRKAES256Extension.h
//  dynamic-test
//
//  Created by Adrian Herridge on 01/08/2016.
//  Copyright © 2016 Adrian Herridge. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (SharkORMEncryption)
- (NSData *)SRKAES256EncryptWithKey:(NSString *)key;
- (NSData *)SRKAES256DecryptWithKey:(NSString *)key;
@end
