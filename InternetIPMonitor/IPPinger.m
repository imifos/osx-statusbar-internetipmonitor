/*
 
 Ping class that contacts the server's PHP file to get back the requestee's IP.
 
 License:
 --------
 This code is free software; you can redistribute it and/or modify it under the terms of the
 GNU General Public License version 3 only, as published by the Free Software Foundation.
 
 This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License version 3 for more details.
 */


#import "IPPinger.h"


/*---------------------------------------------------------------------------------------------------
 *
 */
@interface IPPinger ()
    @property(strong) NSMutableData *responseData;
    @property(strong,nonatomic) void(^completionCallback)(IPPingResult result,NSString *resultIp);
@end



/*---------------------------------------------------------------------------------------------------
 *
 */
@implementation IPPinger

/*
 *
 */
-(id)initWithCompletionCallback:(void(^)(IPPingResult result,NSString *resultIp))callback {
    _completionCallback=callback;
    return self;
}


/*
 *
 */
-(void)doPing {
 
    NSString *requestURLString = @"https://ssl.carl.pro/ipreflector.php";
    
    //NSLog(@"IP ping: %@", requestURLString);
    
    NSURLRequest* request=[NSURLRequest requestWithURL:[NSURL URLWithString:requestURLString]
                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                        timeoutInterval:5.0];
    
    NSURLConnection* connection=[[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    if (connection) {
        _responseData = [NSMutableData data];
        // To be continued below...
    }
    else {
        NSLog(@"Error during NSURLConnection construction");
        _responseData=nil;
        _result=PING_CONNECTIONFAILED;
        _resultIp=@"";
        _completionCallback(_result,_resultIp);
        return;
    }
}


/*
 * A Delegate is used as the server uses a self-signed SSL certificate that we - in this very special case -
 * gladly accept :) Needed to do this: canAuthenticateAgainstProtectionSpace() and didReceiveAuthenticationChallenge().
 * Source of knowledge - the interet.
 */
#pragma mark - NSURLConnectionDelegate methods

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space {
    if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        return YES; // Accept self-signed
    }
    // No for everything else
    return NO;
}

-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    [_responseData setLength:0];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    [_responseData appendData:data];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    
    _responseData=nil;
    
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    _result=PING_CONNECTIONFAILED;
    _resultIp=@"";
    _completionCallback(_result,_resultIp);
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    
    NSString *response=[[NSString alloc] initWithData:_responseData encoding:NSASCIIStringEncoding];
    //NSLog(@"Data %@", response );
    
    _result=PING_SERVICEERROR;
    _resultIp=@"";
    
    NSRange match1=[response rangeOfString: @"#REMOTE_ADDR_"];
    NSRange match2=[response rangeOfString: @"_REMOTE_ADDR#"];
    
    if (match1.location==NSNotFound || match2.location==NSNotFound) {
        NSLog(@"Response does not contain the expected tags.");
        _completionCallback(_result,_resultIp);
        return;
    }
    
    unsigned long length=match2.location-(match1.location+match1.length);
    if (length<7 || length>50) {
        NSLog(@"Response does not contain the expected tags.");
        _completionCallback(_result,_resultIp);
        return;
    }
    
    _resultIp=[response substringWithRange: NSMakeRange (match1.location+match1.length,length)];
    _result=PING_OK;
    
    //NSLog (@"Detected IP: %@",_resultIp);
    
    _completionCallback(_result,_resultIp);
    
    _responseData=nil;
}

#pragma mark -

@end

/*
 #HTTP_CLIENT_IP__HTTP_CLIENT_IP#
 #HTTP_X_FORWARDED_FOR__HTTP_X_FORWARDED_FOR#
 #HTTP_X_FORWARDED__HTTP_X_FORWARDED#
 #HTTP_FORWARDED_FOR__HTTP_FORWARDED_FOR#
 #HTTP_FORWARDED__HTTP_FORWARDED#
 #REMOTE_ADDR_159.8.85.240_REMOTE_ADDR#
 #REMOTE_ADDR2_159.8.85.240_REMOTE_ADDR2#
*/
