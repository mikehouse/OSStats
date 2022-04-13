//
//  AppDelegate.m
//  OSStats
//

#import "AppDelegate.h"
#import "Utilities.h"

static OsStats *statsRef;
static const NSString * kConfigurationTemperatureKey = @"Temperature";
static const NSString * kConfigurationUpdateIntervalKey = @"UpdateInterval";

static const NSString * kStatusBarCPUTemperatureValueKey = @"kStatusBarCPUTemperatureValueKey";
static const NSString * kStatusBarCPUConsumingValueKey = @"kStatusBarCPUConsumingValueKey";
static const NSString * kStatusBarSeparatorValueKey = @"kStatusBarSeparatorValueKey";
static const NSString * kStatusBarSeparatorValue = @" | ";

typedef NS_ENUM(NSUInteger, OSTemperature) {
    OSCelsius = 0,
    OSFahrenheit = 1
};

static OSTemperature temperature = OSCelsius;

typedef NS_ENUM(NSUInteger, OSUpdateInterval) {
    OS3Seconds = 3,
    OS5Seconds = 5,
    OS10Seconds = 10,
    OS30Seconds = 30
};

static OSUpdateInterval updateInterval = OS10Seconds;

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

    [self addMenu];
    [self readPlistConfiguration];
    [self updateStatusBar];
}

- (void)readPlistConfiguration {
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        temperature = [self readTemperatureKind];
        updateInterval = [self readUpdateInterval];
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (temperature) {
                case OSFahrenheit:
                    [self fahrenheitSelected];
                    break;
                default:
                    [self celsiusSelected];
            }

            switch (updateInterval) {
                case OS3Seconds:
                    [self updateInterval3Selected];
                    break;
                case OS5Seconds:
                    [self updateInterval5Selected];
                    break;
                case OS10Seconds:
                    [self updateInterval10Selected];
                    break;
                case OS30Seconds:
                    [self updateInterval30Selected];
                    break;
            }

            [self.updateTimer invalidate];
            self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
                                                                target:self
                                                              selector:@selector(updateStatusBar)
                                                              userInfo:nil repeats:YES];
        });
    }];
    [self.operationQueue addOperation:operation];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updateStatusBar];
}

- (void)updateStatusBar {
    [self updateStatusBarExcludingPid:0];
}

- (void)updateStatusBarExcludingPid:(int)processPid {
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSAssert(!NSThread.isMainThread, @"");
        if (statsRef != NULL) {
            os_stats_free(statsRef);
            statsRef = NULL;
        }
        OsStats *stats = os_stats_exclude_pid(processPid);
        if (stats != NULL) {
            statsRef = stats;
            NSMutableDictionary *statusBarValues = [@{kStatusBarSeparatorValueKey: kStatusBarSeparatorValue} mutableCopy];
            if (stats->cpu_temperature > 0.0) {
                NSUnitTemperature *celsius = [NSUnitTemperature celsius];
                NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:stats->cpu_temperature unit:celsius];
                NSString *symbol = measurement.unit.symbol;
                double temp = measurement.doubleValue;
                if (temperature == OSFahrenheit) {
                    NSMeasurement *fUnit = [measurement measurementByConvertingToUnit:[NSUnitTemperature fahrenheit]];
                    symbol = fUnit.unit.symbol;
                    temp = fUnit.doubleValue;
                }
                statusBarValues[kStatusBarCPUTemperatureValueKey] = [NSString stringWithFormat:
                    @"cpu %0.1lf %@", temp, symbol];
                statusBarValues[kStatusBarCPUConsumingValueKey] = [NSString stringWithFormat:
                    @"%s%% %s", stats->max_consume_proc_value, stats->max_consume_proc_name];
            } else {
                statusBarValues[kStatusBarCPUConsumingValueKey] = [NSString stringWithFormat:
                    @"%s%% %s", stats->max_consume_proc_value, stats->max_consume_proc_name];
            }
            NSOperatingSystemVersion systemVersion = [NSProcessInfo processInfo].operatingSystemVersion;
            NSNumber *offset = @(0);
            if (systemVersion.majorVersion == 11) {
                offset = @(-16);
            } else if (systemVersion.majorVersion == 12) {
                offset = @(-32);
            }
            NSFont *font = [NSFont systemFontOfSize:12];
            NSAttributedString *separator = [[NSAttributedString alloc] initWithString:
                statusBarValues[kStatusBarSeparatorValueKey] attributes:@{
                NSFontAttributeName: font,
                NSBaselineOffsetAttributeName: offset
            }];

            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
            NSString *tmp;
            if ((tmp = statusBarValues[kStatusBarCPUTemperatureValueKey]) != nil) {
                NSAttributedString *temperature = [[NSAttributedString alloc] initWithString:tmp attributes:@{
                    NSFontAttributeName: font,
                    NSBaselineOffsetAttributeName: offset
                }];
                [attributedString appendAttributedString:temperature];
                [attributedString appendAttributedString:[separator copy]];
            }
            if ((tmp = statusBarValues[kStatusBarCPUConsumingValueKey]) != nil) {
                NSMutableDictionary *attrs = [@{
                    NSFontAttributeName: font,
                    NSBaselineOffsetAttributeName: offset
                } mutableCopy];
                if (stats->max_consume_proc_raw_value >= 99.0) {
                    attrs[NSForegroundColorAttributeName] = [NSColor redColor];
                }
                NSAttributedString *consume = [[NSAttributedString alloc] initWithString:tmp attributes:attrs];
                [attributedString appendAttributedString:consume];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusItem.button.attributedTitle = attributedString;
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
                NSString *title = [NSString stringWithFormat:@"Celsius (%@)", [NSUnitTemperature celsius].symbol];
                NSMenuItem *item0 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(celsiusSelected) keyEquivalent:@""];
                [submenu addItem:item0];
                item0.state = NSControlStateValueOn;
            }
            {
                NSString *title = [NSString stringWithFormat:@"Fahrenheit (%@)", [NSUnitTemperature fahrenheit].symbol];
                NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(fahrenheitSelected) keyEquivalent:@""];
                [submenu addItem:item1];
                item1.state = NSControlStateValueOff;
            }
        }
        {
            NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];
            formatter.unitStyle = NSFormattingUnitStyleLong;
            NSUnitDuration *unit = [NSUnitDuration seconds];

            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Update interval"
                                                          action:nil keyEquivalent:@""];
            [menu addItem:item];

            NSMenu *submenu = [NSMenu new];
            [menu setSubmenu:submenu forItem:item];

            {
                enum OSUpdateInterval interval = OS3Seconds;
                NSString *title = [NSString stringWithFormat:@"%lu %@", interval, [formatter stringFromUnit:unit]];
                NSMenuItem *item0 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(updateInterval3Selected) keyEquivalent:@""];
                [submenu addItem:item0];
                item0.state = updateInterval == interval ? NSControlStateValueOn : NSControlStateValueOff;
            }
            {
                enum OSUpdateInterval interval = OS5Seconds;
                NSString *title = [NSString stringWithFormat:@"%lu %@", interval, [formatter stringFromUnit:unit]];
                NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(updateInterval5Selected) keyEquivalent:@""];
                [submenu addItem:item1];
                item1.state = updateInterval == interval ? NSControlStateValueOn : NSControlStateValueOff;
            }
            {
                enum OSUpdateInterval interval = OS10Seconds;
                NSString *title = [NSString stringWithFormat:@"%lu %@", interval, [formatter stringFromUnit:unit]];
                NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(updateInterval10Selected) keyEquivalent:@""];
                [submenu addItem:item1];
                item1.state = updateInterval == interval ? NSControlStateValueOn : NSControlStateValueOff;
            }
            {
                enum OSUpdateInterval interval = OS30Seconds;
                NSString *title = [NSString stringWithFormat:@"%lu %@", interval, [formatter stringFromUnit:unit]];
                NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:title
                                                               action:@selector(updateInterval30Selected) keyEquivalent:@""];
                [submenu addItem:item1];
                item1.state = updateInterval == interval ? NSControlStateValueOn : NSControlStateValueOff;
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
        [[self operationQueue] cancelAllOperations];
        [self updateStatusBarExcludingPid:pid]; // update after a process killed.
    }];
    [self.operationQueue addOperation:operation];
}

#pragma mark - Update Interval menu

- (void)updateInterval3Selected {
    [self updateIntervalSelected: OS3Seconds];
}

- (void)updateInterval5Selected {
    [self updateIntervalSelected: OS5Seconds];
}

- (void)updateInterval10Selected {
    [self updateIntervalSelected: OS10Seconds];
}

- (void)updateInterval30Selected {
    [self updateIntervalSelected: OS30Seconds];
}

- (void)updateIntervalSelected:(OSUpdateInterval)interval {
    updateInterval = interval;
    NSArray<NSMenuItem *> *intervalItems = [self updateIntervalItems];
    NSMenuItem *selectedItem;

    switch (interval) {
        case OS3Seconds:
            selectedItem = [self updateInterval3Item];
            break;
        case OS5Seconds:
            selectedItem = [self updateInterval5Item];
            break;
        case OS10Seconds:
            selectedItem = [self updateInterval10Item];
            break;
        case OS30Seconds:
            selectedItem = [self updateInterval30Item];
            break;
    }

    for (NSMenuItem *item in intervalItems) {
        if (selectedItem == item) {
            item.state = NSControlStateValueOn;
        } else {
            item.state = NSControlStateValueOff;
        }
    }

    [self.updateTimer invalidate];
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(updateStatusBar)
                                                      userInfo:nil repeats:YES];

    [self writeUpdateInterval];
}

- (NSMenuItem *)updateInterval3Item {
    return [[self updateIntervalSubmenu] itemAtIndex:0];
}

- (NSMenuItem *)updateInterval5Item {
    return [[self updateIntervalSubmenu] itemAtIndex:1];
}

- (NSMenuItem *)updateInterval10Item {
    return [[self updateIntervalSubmenu] itemAtIndex:2];
}

- (NSMenuItem *)updateInterval30Item {
    return [[self updateIntervalSubmenu] itemAtIndex:3];
}

- (NSArray<NSMenuItem *> *)updateIntervalItems {
    return @[
        [self updateInterval3Item],
        [self updateInterval5Item],
        [self updateInterval10Item],
        [self updateInterval30Item]
    ];
}

- (NSMenu *)updateIntervalSubmenu {
    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:2];
    return item.submenu;
}

#pragma mark - Temperature Unit menu

- (void)fahrenheitSelected {
    temperature = OSFahrenheit;
    NSMenuItem *fahrenheitItem = [self fahrenheitItem];
    fahrenheitItem.state = NSControlStateValueOn;
    NSMenuItem *celsiusItem = [self celsiusItem];
    celsiusItem.state = NSControlStateValueOff;

    NSMenu *submenu = [self temperatureSubmenu];
    [submenu itemChanged:fahrenheitItem];
    [submenu itemChanged:celsiusItem];

    [self writeTemperature];
}

- (void)celsiusSelected {
    temperature = OSCelsius;
    NSMenuItem *fahrenheitItem = [self fahrenheitItem];
    fahrenheitItem.state = NSControlStateValueOff;
    NSMenuItem *celsiusItem = [self celsiusItem];
    celsiusItem.state = NSControlStateValueOn;

    NSMenu *submenu = [self temperatureSubmenu];
    [submenu itemChanged:fahrenheitItem];
    [submenu itemChanged:celsiusItem];

    [self writeTemperature];
}

- (NSMenuItem *)fahrenheitItem {
    return [[self temperatureSubmenu] itemAtIndex:1];
}

- (NSMenuItem *)celsiusItem {
    return [[self temperatureSubmenu] itemAtIndex:0];
}

- (NSMenu *)temperatureSubmenu {
    NSMenu *menu = self.statusItem.menu;
    NSMenuItem *item = [menu itemAtIndex:1];
    return item.submenu;
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

#pragma mark - Plist write

#pragma mark - Temperature

- (void)writeTemperature {
    [self writeConfigurationValue:@(temperature)
                          withKey:kConfigurationTemperatureKey];
}

- (OSTemperature)readTemperatureKind {
    NSValue *value = [self readConfigurationValueWithKey:kConfigurationTemperatureKey];
    if (value != NULL && [value isKindOfClass:NSNumber.class]) {
        NSNumber *num = (NSNumber *) value;
        switch (num.integerValue) {
            case OSCelsius:
                return OSCelsius;
            case OSFahrenheit:
                return OSFahrenheit;
            default:
                return OSCelsius;
        }
    }
    return OSCelsius;
}

- (void)writeUpdateInterval {
    [self writeConfigurationValue:@(updateInterval)
                          withKey:kConfigurationUpdateIntervalKey];
}

#pragma mark - Update Interval

- (OSUpdateInterval)readUpdateInterval {
    NSValue *value = [self readConfigurationValueWithKey:kConfigurationUpdateIntervalKey];
    if (value != NULL && [value isKindOfClass:NSNumber.class]) {
        NSNumber *num = (NSNumber *) value;
        switch (num.integerValue) {
            case OS3Seconds:
                return OS3Seconds;
            case OS5Seconds:
                return OS5Seconds;
            case OS10Seconds:
                return OS10Seconds;
            case OS30Seconds:
                return OS30Seconds;
            default:
                return OS5Seconds;
        }
    }
    return OS5Seconds;
}

#pragma mark - Configuration API

- (void)writeConfigurationValue:(NSValue *)value withKey:(NSString *)key {
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSMutableDictionary *plist = [[self configurationDictionary] mutableCopy];
        plist[key] = value;
        NSURL *url = [self configurationPlistURLPath];
        NSError *error;
        [plist writeToURL:url error:&error];
        if (error != NULL) {
            NSLog(@"Error %@", error);
        }
    }];
    [self.operationQueue addOperation:operation];
}

- (NSValue *)readConfigurationValueWithKey:(NSString *)key {
    NSDictionary *plist = [self configurationDictionary];
    return plist[key];
}

- (NSURL *)configurationPlistURLPath {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [NSString stringWithFormat:@"%@/configuration.plist", bundle.resourcePath];
    NSURL *resources = [NSURL fileURLWithPath:path isDirectory:NO];
    return resources;
}

- (NSDictionary *)configurationDictionary {
    NSURL *path = [self configurationPlistURLPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path.path]) {
        NSError *error;
        NSDictionary *plist = [[NSDictionary alloc] initWithContentsOfURL:path error:&error];
        if (error != nil) {
            NSLog(@"Error: %@", error);
            return @{};
        }
        return plist;
    } else {
        return @{};
    }
}

@end
