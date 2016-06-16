//
//  SRKFTSQuery
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SharkORM.h"
#import "SRKQuery+Private.h"

@implementation SRKFTSQuery

/* execution methods */

- (SRKQuery *)where:(NSString *)where {
	self.fts = YES;
	return [super where:where];
}

- (SRKQuery *)whereWithFormat:(NSString *)format, ... {
	self.fts = YES;
	va_list args;
	va_start(args, format);
	return [super whereWithFormat:format, args];
	va_end(args);
}

- (SRKQuery *)whereWithFormat:(NSString *)format withParameters:(NSArray *)params {
	self.fts = YES;
	return [super whereWithFormat:format withParameters:params];
}

@end
