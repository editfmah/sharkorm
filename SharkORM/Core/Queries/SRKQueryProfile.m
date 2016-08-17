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