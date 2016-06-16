//
//  SharkORMSettings.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"

@implementation SRKSettings

- (id)init {
	self = [super init];
	if(self){
		
		/* setup the default options */
		self.useEpochDates = YES;
		self.defaultManagedObjects = NO;
		self.defaultObjectDomain = @"default";
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentDirectory = [paths objectAtIndex:0];
		self.databaseLocation = documentDirectory;
		self.defaultDatabaseName = @"database";
		self.encryptionKey = @"bvzdsrthjnbvcxdfrtyuijbvcxdrtyuhjbvcxdfsdfghjcfhjw45678iuojkbnvcxfe5678uijhvgcf";
		self.retainLightweightObjects = NO;
		self.sqliteJournalingMode = @"WAL";
		
	}
	return self;
}

@end
