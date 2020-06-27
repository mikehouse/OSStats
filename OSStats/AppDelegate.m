//
//  AppDelegate.m
//  OSStats
//

#import "AppDelegate.h"
#import "Utilities.h"

NSTimeInterval updateInterval = 5.0;
static OsStats *statsRef;

typedef NS_ENUM(NSUInteger, OSTemperatureKind) {
    OSCelsius = 0,
    OSFahrenheit = 1
};

static OSTemperatureKind temperatureKind = OSCelsius;

@interface AppDelegate () <NSMenuDelegate>

@property(nonatomic) NSStatusItem *statusItem;
@property(nonatomic) NSTimer *updateTimer;
@property(nonatomic) NSOperationQueue *operationQueue;
@property(nonatomic) dispatch_queue_t serial_background_queue;
@property(nonatomic) int processPidAtOpeningMenu;

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
    [barButton sendActionOn:NSEventMaskLeftMouseUp];

    self.statusItem = statusItem;

    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
                                                        target:self selector:@selector(updateStatusBar) userInfo:nil repeats:YES];

    [self addMenu];
    [self updateStatusBar];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updateStatusBar];
}

- (void)updateStatusBar {
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSAssert(!NSThread.isMainThread, @"");
        if (statsRef != NULL) {
            os_stats_free(statsRef);
            statsRef = NULL;
        }
        OsStats *stats = os_stats();
        if (stats != NULL) {
            statsRef = stats;
            NSString *process = nil;
            if (stats->cpu_temperature > 0.0) {
                NSUnitTemperature *celsius = [NSUnitTemperature celsius];
                NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:stats->cpu_temperature unit:celsius];
                NSString *symbol = measurement.unit.symbol;
                double temp = measurement.doubleValue;
                if (temperatureKind == OSFahrenheit) {
                    NSMeasurement *fUnit = [measurement measurementByConvertingToUnit:[NSUnitTemperature fahrenheit]];
                    symbol = fUnit.unit.symbol;
                    temp = fUnit.doubleValue;
                }
                process = [NSString stringWithFormat:@"cpu %0.1lf %@ | %s%% %s", temp, symbol, stats->max_consume_proc_value, stats->max_consume_proc_name];
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
        }
    }];
    [self.operationQueue addOperation:operation];
}

- (void)addMenu {
    if (self.statusItem.menu == nil) {
        NSMenu *menu = [NSMenu new];
        menu.delegate = self;
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Activity Monitor"
                                                          action:@selector(launchActivityMonitorApp) keyEquivalent:@""];
            [menu addItem:item];
        }
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Temperature"
                                                          action:nil keyEquivalent:@""];
            [menu addItem:item];

            NSMenu *submenu = [NSMenu new];
            [menu setSubmenu:submenu forItem:item];

            {
                NSMenuItem *item0 = [[NSMenuItem alloc] initWithTitle:@"Celsius (°C)"
                                                               action:@selector(celsiusSelected) keyEquivalent:@""];
                [submenu addItem:item0];
                item0.state = NSControlStateValueOn;
            }
            {
                NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:@"Fahrenheit (°F)"
                                                               action:@selector(fahrenheitSelected) keyEquivalent:@""];
                [submenu addItem:item1];
                item1.state = NSControlStateValueOff;
            }
        }
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Kill process"
                                                          action:@selector(kill9) keyEquivalent:@""];
            [menu addItem:item];
        }
        {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                          action:@selector(exitApp) keyEquivalent:@""];
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

- (void)kill9 {
    int pidBeforeKill = self.processPidAtOpeningMenu;
    self.processPidAtOpeningMenu = 0;
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        OsStats *stats = statsRef;
        if (stats == NULL) {
            return;
        }

        int pid = stats->pid;

        if (pidBeforeKill != pid) {
            // User was too slow to select kill process that the selected process
            // already ended or is not already most expensive process.
            return;
        }

        kill9(pid);

        [self updateStatusBar]; // update after a process killed.
    }];
    [self.operationQueue addOperation:operation];
}

- (void)fahrenheitSelected {
    temperatureKind = OSFahrenheit;
    NSMenuItem *fahrenheitItem = [self fahrenheitItem];
    fahrenheitItem.state = NSControlStateValueOn;
    NSMenuItem *celsiusItem = [self celsiusItem];
    celsiusItem.state = NSControlStateValueOff;

    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:1];
    NSMenu *submenu = item.submenu;
    [submenu itemChanged:fahrenheitItem];
    [submenu itemChanged:celsiusItem];
}

- (void)celsiusSelected {
    temperatureKind = OSCelsius;
    NSMenuItem *fahrenheitItem = [self fahrenheitItem];
    fahrenheitItem.state = NSControlStateValueOff;
    NSMenuItem *celsiusItem = [self celsiusItem];
    celsiusItem.state = NSControlStateValueOn;

    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:1];
    NSMenu *submenu = item.submenu;
    [submenu itemChanged:fahrenheitItem];
    [submenu itemChanged:celsiusItem];
}

- (NSMenuItem *)fahrenheitItem {
    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:1];
    NSMenu *submenu = item.submenu;
    return [submenu itemAtIndex:1];
}

- (NSMenuItem *)celsiusItem {
    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:1];
    NSMenu *submenu = item.submenu;
    return [submenu itemAtIndex:0];
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    if (self.statusItem.menu == menu) {
        OsStats *stats = statsRef;
        if (stats == NULL) {
            return;
        }
        self.processPidAtOpeningMenu = stats->pid;
    }
}

@end
