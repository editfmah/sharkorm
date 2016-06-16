//
//  SRKLazyLoader.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"

@interface SRKLazyLoader : NSObject {
	
}

@property (nonatomic, strong) SRKRelationship*    relationship;
@property (nonatomic, weak) NSObject*            parentEntity;
@property (nonatomic, weak) NSObject*            relatedEntity;
@property BOOL exists;

- (void)reset;
- (id)fetchNode;

@end
