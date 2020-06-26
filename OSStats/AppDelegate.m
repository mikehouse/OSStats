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
@property(nonatomic) NSOperationQueue *operationQueue;
@property(nonatomic) dispatch_queue_t serial_background_queue;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    dispatch_queue_t dispatchQueueCreate = dispatch_queue_create("os.stats.queue.serial", DISPATCH_QUEUE_SERIAL);

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    queue.underlyingQueue = dispatchQueueCreate;

    self.operationQueue = queue;
    self.serial_background_queue = dispatchQueueCreate;

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
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSAssert(!NSThread.isMainThread, @"");
        OsStats *stats = os_stats();
        if (stats != NULL) {
            NSString *process = nil;
            if (stats->cpu_temperature > 0.0) {
                process = [NSString stringWithFormat:@"cpu %0.1lf °C %s%% %s", stats->cpu_temperature, stats->max_consume_proc_value, stats->max_consume_proc_name];
            } else {
                process = [NSString stringWithFormat:@"cpu %s%% %s", stats->max_consume_proc_value, stats->max_consume_proc_name];
            }
            NSOperatingSystemVersion systemVersion = [NSProcessInfo processInfo].operatingSystemVersion;
            NSNumber *offset = systemVersion.minorVersion >= 16 ? @(0) : @(-16);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusItem.button.attributedTitle = [[NSAttributedString alloc] initWithString:process attributes:@{
                    NSFontAttributeName: [NSFont systemFontOfSize:12],
                    NSBaselineOffsetAttributeName: offset // 🤷‍♂️
                }];
            });
            os_stats_free(stats);
        }
    }];
    [self.operationQueue addOperation:operation];
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
