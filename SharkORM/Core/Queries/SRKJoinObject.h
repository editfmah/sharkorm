//
//  SRKJoinObject.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRKJoinObject : NSObject

@property (strong) Class       joinOn;
@property (strong) NSString*   joinWhere;
@property (strong) NSString*   joinLeft;
@property (strong) NSString*   joinRight;

- (instancetype)setJoinOn:(Class)joinOn joinWhere:(NSString*)joinWhere joinLeft:(NSString*)joinLeft joinRight:(NSString*)joinRight;

@end
