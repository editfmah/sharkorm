//
//  SRKQueryProfile.m
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import "SharkORM.h"

@implementation SRKQueryProfile

@synthesize rows,parseTime,queryPlan,queryTime, sqlQuery, resultsSet, firstResultTime, lockObtainTime;

- (NSString*)description {
	
	NSString* plan = @"";
	for (NSDictionary* d in self.queryPlan) {
		plan = [plan stringByAppendingFormat:@" Order:%@  From:%@  Usage: %@", [d objectForKey:@"order"], [d objectForKey:@"from"], [d objectForKey:@"detail"]];
	}
	
	NSString* outStr = [NSString stringWithFormat:@"\n\nDB Query Profiler\n------------------------------------------------------------------------------------------\nQuery Time:%i ms  Lock Wait:%i ms  Parse Time:%i ms  Seek Time:%i ms  Row Count:%lu\n------------------------------------------------------------------------------------------\nSQL Query\n------------------------------------------------------------------------------------------\n%@\n------------------------------------------------------------------------------------------\nSQLITE3 QUERY PLAN\n------------------------------------------------------------------------------------------\n%@\n------------------------------------------------------------------------------------------\n\n", queryTime, lockObtainTime ,parseTime, firstResultTime, (unsigned long)((NSArray*)resultsSet).count,sqlQuery, plan];
	
	return outStr;
	
}

@end