//
//  AppDelegate.m
//  OSStats
//

#import "AppDelegate.h"
#import "Utilities.h"

NSTimeInterval updateInterval = 5.0;

@interface AppDelegate ()

@property(nonatomic) NSStatusItem *statusItem;
@property(nonatomic) NSTimer *updateTimer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = [statusBar statusItemWithLength:-1];
    NSStatusBarButton *barButton = statusItem.button;
    barButton.target = self;
    barButton.action = @selector(tapped:);

    self.statusItem = statusItem;

    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
        target:self selector:@selector(updateStatusBar) userInfo:nil repeats:YES];

    [self addMenu];
    [self updateStatusBar];
}

- (void)tapped:(NSStatusItem *)sender {
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updateStatusBar];
}

- (void)updateStatusBar {
    char *string = getMostHeavySystemCPUConsumer();
    if (string != NULL) {
        NSString *process = [NSString stringWithFormat:@"cpu %s", string];
        self.statusItem.button.attributedTitle = [[NSAttributedString alloc] initWithString:process attributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:12],
            NSBaselineOffsetAttributeName: @(-16) // 🤷‍♂️
        }];
        free(string);
    }
}

- (void)addMenu {
    if (self.statusItem.menu == nil) {
        NSMenu *menu = [NSMenu new];
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Activity Monitor"
                action:@selector(launchActivityMonitorApp) keyEquivalent:@"A"];
            [menu addItem:item];
        }
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Quit"
                action:@selector(exitApp) keyEquivalent:@"Q"];
            [menu addItem:item];
        }
        self.statusItem.menu = menu;
    }
}

- (void)launchActivityMonitorApp {
    NSURL *url = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.apple.ActivityMonitor"];
    if (url == nil) {
        return;
    }
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url
                                        configuration:[NSWorkspaceOpenConfiguration configuration]
                                    completionHandler:nil];
}

- (void)exitApp {
    [[NSApplication sharedApplication] terminate:self];
}

@end
