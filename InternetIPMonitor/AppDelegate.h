#import <Cocoa/Cocoa.h>


typedef NS_ENUM(NSUInteger, DisplayOption) {
    DISPLAY_SHORT,
    DISPLAY_SHOWIP
};

typedef NS_ENUM(NSUInteger, State) {
    STATE_UNTESTED,         // Not yet "pinged"
    STATE_NOCONNECTION,     // Cannot get to the ping server
    STATE_SERVICEBROKEN,    // Ping server responds, but service is not working as expected
    STATE_IP_UNCLASSIFIED,
    STATE_IP_GOOD,
    STATE_IP_BAD
};



@interface AppDelegate : NSObject <NSApplicationDelegate>

// GUI
@property(strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property(strong, nonatomic) NSStatusItem *statusItem;
@property(strong, nonatomic) IBOutlet NSMenuItem *markGoodMenuItem;
@property(strong, nonatomic) IBOutlet NSMenuItem *markBadMenuItem;
@property(strong, nonatomic) IBOutlet NSMenuItem *markUnclassifiedMenuItem;
@property(strong, nonatomic) IBOutlet NSMenuItem *clearMarkedMenuItem;


// State
@property(strong, nonatomic) NSString* currentIp;
@property State state;
@property DisplayOption displayOption;

// GUI Callbacks
- (IBAction)onMarkGood:(id)sender;
- (IBAction)onMarkBad:(id)sender;
- (IBAction)onMarkUnclassified:(id)sender;
- (IBAction)onClearMarked:(id)sender;

@end
