//
//  SyncNetwork.m
//  SharkORM
//
//  Created by Adrian Herridge on 16/07/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

#import "SyncNetwork.h"
#import "SyncRequest.h"

static SyncNetwork* __this;

@interface SyncNetwork()

@property (strong) dispatch_queue_t queue;

@end

@implementation SyncNetwork {
    dispatch_block_t currentBlock;
}

+ (instancetype)sharedInstance {
    if (!__this) {
        __this = [SyncNetwork new];
        __this.queue = dispatch_queue_create("SharkSync.io.SyncQueue", nil);
    }
    return __this;
}

- (void)queueNextRequest {
    
    __weak SyncNetwork* wSelf = self;
    
    currentBlock = ^(){
        
        @synchronized([SharkSync sharedObject].currentGroups) {
            
            int count = 0;
            uint64_t time = @([NSDate date].timeIntervalSince1970 * 1000).unsignedLongLongValue;
            for (SharkSyncGroup* g in [SharkSync sharedObject].currentGroups) {
                if ((g.lastPolled + g.frequency) < time) {
                    count++;
                }
            }
            if ([SharkSync sharedObject].countOfChangesToSyncUp > 0 || count != 0) {
                
                // create a request object and then, if it contains data, dispatch it on the queue
                SyncRequestObject* reqObject = [SyncRequest generateSyncRequest];
                
                NSURL *url = [NSURL URLWithString:SharkSync.Settings.serviceUrl];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                
                NSError *error;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:reqObject.request options:0 error:&error];
                
                NSString *jsonString;
                if (! jsonData) {
                    NSLog(@"Got an error: %@", error);
                } else {
                    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    
                    NSData *requestData = [NSData dataWithBytes:[jsonString UTF8String] length:[jsonString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
                    
                    [request setHTTPMethod:@"POST"];
                    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
                    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
                    [request setHTTPBody: requestData];
                    
                    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                        // this runs on background thread
                        
                        if (error != nil) {
                            [SyncRequest handleError:error request:reqObject];
                            [NSThread sleepForTimeInterval:5];
                            [wSelf queueNextRequest];
                            return;
                        }
                        
                        if (response && ((NSHTTPURLResponse*)response).statusCode != 200) {
                            [SyncRequest handleError:[NSError errorWithDomain:@"sharksync.io.error" code:((NSHTTPURLResponse*)response).statusCode userInfo:@{@"HTTP Error Code" : @"A response code other than 200 was received by the ORM."}] request:reqObject];
                            [NSThread sleepForTimeInterval:5];
                            [wSelf queueNextRequest];
                            return;
                        }
                        
                        error = nil;
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                        if (error) {
                            [SyncRequest handleError:error request:reqObject];
                            [NSThread sleepForTimeInterval:5];
                            [wSelf queueNextRequest];
                            return;
                        }
                        
                        [SyncRequest handleResponse:json request:reqObject];
                        [NSThread sleepForTimeInterval:1];
                        [wSelf queueNextRequest];
                        return;
                        
                        
                    }];
                }
                
            } else {
                [NSThread sleepForTimeInterval:5];
                [wSelf queueNextRequest];
        }
    }
};

dispatch_async(_queue, currentBlock);

}

- (void)startService {
    
    // queue an operation block which repetitively calls the service
    dispatch_resume(_queue);
    [self queueNextRequest];
    
}

- (void)stopService {
    if (currentBlock) {
        dispatch_block_cancel(currentBlock);
    }
    dispatch_suspend(_queue);
}

@end
