//
//  PersonSync.h
//  SharkORMTests
//
//  Created by Adrian Herridge on 18/07/2018.
//  Copyright © 2018 Adrian Herridge. All rights reserved.
//

#import <SharkORM/SharkORM.h>

@interface PersonSync : SRKSyncObject

@property NSString*         name;
@property int               age;
@property int               seq;
@property int               payrollNumber;

@end
