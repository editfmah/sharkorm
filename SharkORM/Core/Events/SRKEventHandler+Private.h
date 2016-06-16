//
//  SRKEventHandler+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKEventHandler_Private_h
#define SRKEventHandler_Private_h

@interface SRKEventHandler () {
	/* iVars for the query parameters */
	Class           classDecl;
	NSMutableArray* registeredEventBlocks;
}

- (Class)classDecl;
- (void)triggerInternalEvent:(SRKEvent*)e;

@end

#endif /* SRKEventHandler_Private_h */
