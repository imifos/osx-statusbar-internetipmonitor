

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, IPPingResult) {
    PING_CONNECTIONFAILED,
    PING_SERVICEERROR,
    PING_OK
};


@interface IPPinger : NSObject<NSURLConnectionDelegate>

    -(id)initWithCompletionCallback:(void(^)(IPPingResult result,NSString *resultIp))callback;

    -(void)doPing;

    // Result of last operation, also passed to callback
    @property IPPingResult result;
    @property(strong, atomic) NSString *resultIp;

@end
