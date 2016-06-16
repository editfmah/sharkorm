//
//  SRKQueryAsyncHandler+Private.h
//  SharkORM
//
//  Copyright © 2016 SharkSync. All rights reserved.
//

#ifndef SRKQueryAsyncHandler_Private_h
#define SRKQueryAsyncHandler_Private_h

@interface SRKQueryAsyncHandler ()

@property (strong) SRKQuery* query;
@property (copy) SRKQueryAsyncResponse block;
@property BOOL onMainThread;

- (id)initWithQuery:(SRKQuery*)set andAsyncBlock:(SRKQueryAsyncResponse)block;

@end

#endif /* SRKQueryAsyncHandler_Private_h */
