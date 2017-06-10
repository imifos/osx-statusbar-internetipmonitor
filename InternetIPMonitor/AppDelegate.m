/*
 License:
 --------
 This code is free software; you can redistribute it and/or modify it under the terms of the 
 GNU General Public License version 3 only, as published by the Free Software Foundation.
 
 This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without 
 even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
 General Public License version 3 for more details.
*/

/*
  Notes:
  - If an application icon is needed in the task bar, set "Application is an Agent" to NO in Info.plist.
*/

#import "AppDelegate.h"
#import "IPPinger.h"

//#import <objc/runtime.h>
//#import <SystemConfiguration/SystemConfiguration.h>



/*---------------------------------------------------------------------------------------------------
 *
 */
@interface AppDelegate ()

@property(weak) IBOutlet NSWindow *window;

@property(strong) IPPinger *pinger;
@property(strong) NSTimer* pingTimer;
@property(strong) NSMutableArray *knownGoodIPs;
@property(strong) NSMutableArray *knownBadIPs;

- (void)updateDisplayState;
- (void)updateStatusBarDisplay;
- (void)updateMenuState;

- (void)onPingTimer:(NSTimer*)timer;

- (void)handlePingCompleted:(IPPingResult)result detectedIp:(NSString*)resultIp;
- (State)getStateForIP:(NSString*)ip;
- (void)addToKnownGood:(NSString*)ip;
- (void)addToKnownBad:(NSString*)ip;
- (void)removeFromKnown:(NSString*)ip;

@property (nonatomic, readonly, strong) NSArray* interfaces;

@end





/*---------------------------------------------------------------------------------------------------
 *
 */
@implementation AppDelegate


/*
 * On initialising the application.
 */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}


/*
 * On application tear down.
 */
- (void)applicationWillTerminate:(NSNotification *)aNotification {
        
    [_pingTimer invalidate];
    
    NSLog(@"Save:");
    for (NSString *text in _knownGoodIPs) {
        NSLog(@"  Known Good: %@", text);
    }
    for (NSString *text in _knownBadIPs) {
        NSLog(@"  Known Bad: %@", text);
    }
        
    // Write classified IPs into user's registry
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:_knownGoodIPs forKey:@"KnownGoodIPs"];
    [defaults setValue:_knownBadIPs forKey:@"KnownBadIPs"];
    [defaults synchronize];
}


/*
 * The nib-loading infrastructure sends an awakeFromNib message to each object recreated from a nib archive,
 * but only after all the objects in the archive have been loaded and initialized. When an object receives
 * an awakeFromNib message, it is guaranteed to have all its outlet and action connections already established.
 *
 * https://developer.apple.com/reference/objectivec/nsobject/1402907-awakefromnib
 */
- (void) awakeFromNib {
    
    NSLog(@"Start-up (awakeFromNib)");
        
    // GUI
    _statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] init];
    [_statusItem setMenu:_statusMenu];
    [_statusItem setHighlightMode:(true)];

    // Get persistent good/bad lists
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _knownGoodIPs = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"KnownGoodIPs"]];
    if (!_knownGoodIPs)
        _knownGoodIPs=[NSMutableArray array];
    _knownBadIPs = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"KnownBadIPs"]];
    if (!_knownBadIPs)
        _knownBadIPs=[NSMutableArray array];
        
    NSLog(@"Loaded:");
    for (NSString *text in _knownGoodIPs) {
        NSLog(@"  Known Good: %@", text);
    }
    for (NSString *text in _knownBadIPs) {
        NSLog(@"  Known Bad: %@", text);
    }
        
    // Initial state
    _state=STATE_UNTESTED;
    _displayOption=DISPLAY_SHOWIP;
    _currentIp=@"";

    [self updateDisplayState];
    
    // Network ping service
    _pinger=[[IPPinger alloc] initWithCompletionCallback:^(IPPingResult result, NSString *resultIp) {
        // Lamba/Block as completion callback
        [self handlePingCompleted:result detectedIp: resultIp];
    }];
    
    // Ping timer
    _pingTimer = [NSTimer scheduledTimerWithTimeInterval:20 target:self selector:@selector(onPingTimer:) userInfo:nil repeats:YES];
    [_pinger doPing];
}


/*
 *
 */
-(void)onPingTimer:(NSTimer *)timer {
    [_pinger doPing];
}


/*
 *
 */
- (IBAction)onMarkGood:(id)sender {
    
    NSLog(@"Mark current IP as GOOD: %@",_currentIp);

    [self addToKnownGood:_currentIp];
    _state=[self getStateForIP:_currentIp];
    
    [self updateDisplayState];
}


/*
 *
 */
- (IBAction)onMarkBad:(id)sender {
    
    NSLog(@"Mark current IP as BAD: %@",_currentIp);
    
    [self addToKnownBad:_currentIp];
    _state=[self getStateForIP:_currentIp];
    
    [self updateDisplayState];
}


/*
 *
 */
- (IBAction)onClearMarked:(id)sender {
    
    NSLog(@"Clear marked IPs.");
    
    [self clearKnown];
    _state=[self getStateForIP:_currentIp];
    
    [self updateDisplayState];
}


/*
 *
 */
- (IBAction)onMarkUnclassified:(id)sender {
    
    NSLog(@"Mark current IP as UNCLASSIFIED: %@",_currentIp);
    
    [self removeFromKnown:_currentIp];
    _state=[self getStateForIP:_currentIp];
   
    [self updateDisplayState];
}


/*
 *
 */
- (void)handlePingCompleted:(IPPingResult)result detectedIp:(NSString*)resultIp {
    
    if ([resultIp isNotEqualTo:_currentIp]) {
        NSLog(@"IP change detected. From %@ to %@",_currentIp,resultIp);
    }
    
    switch(result) {
        
        case PING_OK:
            _currentIp=resultIp;
            _state=[self getStateForIP:resultIp];
            break;
        
        case PING_CONNECTIONFAILED:
            _currentIp=@"";
            _state=STATE_NOCONNECTION;
            break;
        
        default:
            _currentIp=@"";
            _state=STATE_SERVICEBROKEN;
            break;
    }
    
    [self updateDisplayState];
}


/*
 *
 */
- (State)getStateForIP:(NSString*)ip {
    
    if ([_knownBadIPs containsObject:ip])
        return STATE_IP_BAD;
    
    if ([_knownGoodIPs containsObject:ip])
        return STATE_IP_GOOD;
    
    return STATE_IP_UNCLASSIFIED;
}


/*
 *
 */
- (void)addToKnownGood:(NSString*)ip {
    [self removeFromKnown:ip];
    [_knownGoodIPs addObject:ip];
}


/*
 *
 */
- (void)addToKnownBad:(NSString*)ip {
    [self removeFromKnown:ip];
    [_knownBadIPs addObject:ip];
}


/*
 *
 */
- (void)removeFromKnown:(NSString*)ip {
    [_knownGoodIPs removeObject:ip];
    [_knownBadIPs removeObject:ip];
}


/*
 *
 */
- (void)clearKnown {
    [_knownGoodIPs removeAllObjects];
    [_knownBadIPs removeAllObjects];
}


/*
 * Updates the display state in function of the current state of known data.
 */
- (void)updateDisplayState {
    [self updateMenuState];
    [self updateStatusBarDisplay];
}


/*
 *
 */
- (void)updateMenuState {
    
    // Non-operational states
    
    switch(_state) {
        case STATE_SERVICEBROKEN:
        case STATE_NOCONNECTION:
        case STATE_UNTESTED:
            
            [_markGoodMenuItem setEnabled:NO];
            [_markBadMenuItem setEnabled:NO];
            [_markUnclassifiedMenuItem setEnabled:NO];
            
            [_markGoodMenuItem setState:NSOffState];
            [_markBadMenuItem setState:NSOffState];
            [_markUnclassifiedMenuItem setState:NSOffState];
            return;
    }
    
    // Operational states
    
    [_markGoodMenuItem setEnabled:YES];
    [_markBadMenuItem setEnabled:YES];
    [_markUnclassifiedMenuItem setEnabled:YES];
    
    if (_state==STATE_IP_GOOD) {
        [_markGoodMenuItem setState:NSOnState];
        [_markBadMenuItem setState:NSOffState];
        [_markUnclassifiedMenuItem setState:NSOffState];
    }
    else if (_state==STATE_IP_BAD) {
        [_markGoodMenuItem setState:NSOffState];
        [_markBadMenuItem setState:NSOnState];
        [_markUnclassifiedMenuItem setState:NSOffState];
    }
    else if (_state==STATE_IP_UNCLASSIFIED) {
        [_markGoodMenuItem setState:NSOffState];
        [_markBadMenuItem setState:NSOffState];
        [_markUnclassifiedMenuItem setState:NSOnState];
    }
    else
        NSLog(@"BUG! Menu state cannot be determined! Go and hit the developer...");
}



/*
 * Updates the status bar display to reflect the current state.
 */
- (void)updateStatusBarDisplay {
   
        NSColor *titleColor=[NSColor whiteColor];
        NSMutableString *title=[NSMutableString string];
        
        switch(_displayOption) {
            case DISPLAY_SHORT:
                [title appendString:@"IP"];
                break;
            default:
                [title appendString:_currentIp];
                break;
        }
        
        switch(_state) {
                
            case STATE_IP_GOOD:
                [title appendString:@" \u2705"];
                titleColor=[NSColor greenColor];
                [_statusItem setToolTip:@"This IP is classified as good!"];
                break;
                
            case STATE_IP_BAD:
                [title appendString:@" \u274c"];
                titleColor=[NSColor redColor];
                [_statusItem setToolTip:@"This IP is classified as bad!"];
                break;
                
            case STATE_IP_UNCLASSIFIED:
                [title appendString:@"\u2754"];
                titleColor=[NSColor yellowColor];
                [_statusItem setToolTip:@"This IP is not classified yet. Please open the configuration window to do so."];
                break;
                
            case STATE_UNTESTED:
                [title setString:@"IP\u26cf"];
                titleColor=[NSColor grayColor];
                [_statusItem setToolTip:@"Current IP is currently determined."];
                break;
                
            case STATE_NOCONNECTION:
                [title setString:@"IP\u26d4"];
                titleColor=[NSColor grayColor];
                [_statusItem setToolTip:@"Can't reach the ping server. Either the service is down or not connected to the Internet."];
                break;
                
            case STATE_SERVICEBROKEN:
                [title setString:@"ERR"];
                titleColor=[NSColor redColor];
                [_statusItem setToolTip:@"The ping server has been contacted, but the service does not respond in an expected way. Please check the tool homepage."];
                break;
                
            default:
                [title setString:@"ERR"];
                titleColor=[NSColor purpleColor];
                [_statusItem setToolTip:@"Unexpected internal state. You just found a bug. Sorry. Please check the tool homepage."];
                break;
        }
        
        id objects[] = { titleColor, [NSFont fontWithName:@"Arial" size:9] };
        id keys[] = { NSForegroundColorAttributeName, NSFontAttributeName };
        NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:2];
        
        NSAttributedString* attributedtitle = [[NSAttributedString alloc] initWithString:title attributes:titleAttributes];
        
        [_statusItem setAttributedTitle:attributedtitle];
}

@end




/*
Tests for later extensions :)

 _interfaces = (__bridge NSArray*)SCNetworkInterfaceCopyAll();
 
 for ( id i in _interfaces) {
 NSLog(@"%s", class_getName([i class]));
 NSLog(@"%@", i );
 SCNetworkInterfaceRef i2=(__bridge SCNetworkInterfaceRef)(i);
 CFStringRef options=(__bridge CFStringRef)@"EAPOL";
 NSDictionary *d2=(__bridge NSDictionary* )SCNetworkInterfaceGetExtendedConfiguration(i2,options); // <-- does not work, don't try this at home
 NSDictionary *d1=(__bridge NSDictionary* )SCNetworkInterfaceGetConfiguration(i2);
 CFRelease((__bridge CFTypeRef)(d2)); // needed or not, only the ARC knows...
 
 
 NSHost* myHost =[NSHost currentHost];
 if (myHost) {
   NSArray *addresses = [myHost addresses];
 
   for (NSString *address in addresses) {
    NSLog(@"%@", address );
   }
 }
 
 
*/
