//
//  main.m
//  OSStats
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

AppDelegate *appDelegateRef;

int main(int argc, const char * argv[]) {
    AppDelegate *appDelegate = [AppDelegate new];
    appDelegateRef = appDelegate;
    [NSApplication sharedApplication].delegate = appDelegate;
    return NSApplicationMain(argc, argv);
}
