//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
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


#import "SyncNetwork.h"
#import "SyncRequest.h"

static SyncNetwork* __this;

@interface SyncNetwork()

@property (strong) dispatch_queue_t queue;
@property BOOL running;

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
    
    if (self.running == NO) {
        return;
    }
    
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
    
    self.running = YES;
    // queue an operation block which repetitively calls the service
    [self queueNextRequest];
    
}

- (void)stopService {
    self.running = NO;
}

@end
