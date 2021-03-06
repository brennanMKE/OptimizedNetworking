//
//  ONHeadRequestOpertion.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/19/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONHeadRequestOperation.h"

#import "ONNetworkManager.h"

#ifndef NS_BLOCK_ASSERTIONS

// Credit: http://sstools.co/maassert
#define MAAssert(expression, ...) \
do { \
if(!(expression)) { \
NSLog(@"Assertion failure: %s in %s on line %s:%d. %@", #expression, __func__, __FILE__, __LINE__, [NSString stringWithFormat: @"" __VA_ARGS__]); \
abort(); \
} \
} while(0)

#else

#define MAAssert(expression, ...)

#endif

@implementation ONHeadRequestOperation

- (NSString *)httpMethod {
    return @"HEAD";
}

- (void)finishNetworkOperation {
    [super finishNetworkOperation];
    
    @synchronized (self) {
        // assemble dictionary and call headRequestCompletionHandler
        
        if (self.error != nil) {
            if (self.headRequestCompletionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.headRequestCompletionHandler(nil, self.error);
                });
            }
        }
        else {
            // a non-HTTP response will fail the following assertion
            NSAssert(self.response != nil, @"Invalid State");
            
            // parse header values from response and build dictionary to return
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            NSHTTPURLResponse *response = self.response;
            
            //> curl --head http://www.acme.com/data.xml
            //HTTP/1.1 200 OK
            //Date: Thu, 19 Jul 2012 19:09:44 GMT
            //Server: Apache
            //Last-Modified: Wed, 11 Jul 2012 15:03:49 GMT
            //ETag: "182eb49-cec8-4c48f27815f40"
            //Accept-Ranges: bytes
            //Content-Length: 52936
            //Connection: close
            //Content-Type: application/xml
            
            [dict setValue:[NSNumber numberWithInt:(int)response.statusCode] forKey:@"statusCode"];
            NSString *contentType = [[response allHeaderFields] objectForKey:@"Content-Type"];
            if (contentType != nil) {
                [dict setValue:contentType forKey:@"contentType"];
            }
            
            NSString *lastModifiedString = [[response allHeaderFields] objectForKey:@"Last-Modified"];
            NSDate *lastModified = [self parseRFC822DateString:lastModifiedString];
            
            if (lastModified != nil) {
                [dict setValue:lastModified forKey:@"lastModified"];
            }
            
            NSString *eTag = [[response allHeaderFields] objectForKey:@"ETag"];
            if (eTag != nil) {
                [dict setValue:eTag forKey:@"eTag"];
            }
            
            NSUInteger contentLength = [[[response allHeaderFields] objectForKey:@"Content-Length"] intValue];
            [dict setValue:[NSNumber numberWithInt:(int)contentLength] forKey:@"contentLength"];
            
            if (self.headRequestCompletionHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.headRequestCompletionHandler(dict, nil);
                });
            }
        }
    }
}

+ (void)addHeadRequestOperationWithURL:(NSURL *)url withHeadRequestCompletionHandler:(ONHeadRequestOperationCompletionHandler)headRequestCompletionHandler {
    ONHeadRequestOperation *operation = [[ONHeadRequestOperation alloc] init];
    operation.url = url;
    operation.headRequestCompletionHandler = headRequestCompletionHandler;
    operation.completionHandler = ^(NSData *data, NSError *error) {}; // do nothing
    
    [[ONNetworkManager sharedInstance] addOperation:operation];
}

#pragma mark - Private
#pragma mark -

- (NSDate *)parseRFC822DateString:(NSString *)dateString {
    NSString *format = @"EEE, dd MMM yyyy HH:mm:ss zzz";
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [formatter setLocale:usLocale];
    NSDate *date = [formatter dateFromString:dateString];
    
    return date;
}

@end
