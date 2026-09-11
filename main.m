#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSStatusItem *statusItem;
@property (strong) NSMenu *statusMenu;

@property (strong) NSImage *naturalStatusImage;
@property (strong) NSImage *traditionalStatusImage;

@property (strong) NSMenuItem *naturalMenuItem;
@property (strong) NSMenuItem *traditionalMenuItem;
@property (strong) NSMenuItem *launchAtLoginMenuItem;

@end


@implementation AppDelegate

#pragma mark - Scroll setting

- (BOOL)isNaturalScrolling {
    NSString *value =
        [[NSUserDefaults standardUserDefaults]
            persistentDomainForName:NSGlobalDomain]
            [@"com.apple.swipescrolldirection"];

    if (!value) {
        return YES;
    }

    return [value boolValue];
}


- (void)applyScrollSetting:(BOOL)natural {
    NSTask *defaultsTask = [[NSTask alloc] init];

    defaultsTask.launchPath = @"/usr/bin/defaults";
    defaultsTask.arguments = @[
        @"write",
        @"-g",
        @"com.apple.swipescrolldirection",
        @"-bool",
        natural ? @"true" : @"false"
    ];

    [defaultsTask launch];
    [defaultsTask waitUntilExit];

    if (defaultsTask.terminationStatus != 0) {
        NSLog(@"Failed to write scrolling preference");
        return;
    }

    NSTask *activateTask = [[NSTask alloc] init];

    activateTask.launchPath =
        @"/System/Library/PrivateFrameworks/"
         "SystemAdministration.framework/Resources/"
         "activateSettings";

    activateTask.arguments = @[@"-u"];

    [activateTask launch];
    [activateTask waitUntilExit];

    if (activateTask.terminationStatus != 0) {
        NSLog(@"activateSettings failed");
    }
}


#pragma mark - UI updates

- (NSImage *)statusImageForNaturalScrolling:(BOOL)natural {
    NSImage *cachedImage =
        natural
            ? self.naturalStatusImage
            : self.traditionalStatusImage;

    if (cachedImage) {
        return cachedImage;
    }

    NSImageSymbolConfiguration *activeConfiguration =
        [NSImageSymbolConfiguration
            configurationWithPointSize:8.0
                              weight:NSFontWeightSemibold];

    NSImageSymbolConfiguration *inactiveConfiguration =
        [NSImageSymbolConfiguration
            configurationWithPointSize:8.0
                              weight:NSFontWeightRegular];

    NSImage *upArrow =
        [[NSImage imageWithSystemSymbolName:@"arrow.up"
                  accessibilityDescription:nil]
            imageWithSymbolConfiguration:
                natural
                    ? activeConfiguration
                    : inactiveConfiguration];

    NSImage *downArrow =
        [[NSImage imageWithSystemSymbolName:@"arrow.down"
                  accessibilityDescription:nil]
            imageWithSymbolConfiguration:
                natural
                    ? inactiveConfiguration
                    : activeConfiguration];

    NSSize iconSize = NSMakeSize(18.0, 18.0);

    NSImage *image =
        [NSImage imageWithSize:iconSize
                      flipped:NO
               drawingHandler:^BOOL(NSRect destinationRect) {
        NSRect upRect = NSMakeRect(
            NSMidX(destinationRect) - upArrow.size.width / 2.0,
            9.25,
            upArrow.size.width,
            upArrow.size.height);

        NSRect downRect = NSMakeRect(
            NSMidX(destinationRect) - downArrow.size.width / 2.0,
            0.75,
            downArrow.size.width,
            downArrow.size.height);

        [upArrow drawInRect:upRect
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:natural ? 1.0 : 0.38
             respectFlipped:YES
                      hints:nil];

        [downArrow drawInRect:downRect
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:natural ? 0.38 : 1.0
               respectFlipped:YES
                        hints:nil];

        return YES;
    }];

    image.template = YES;

    if (natural) {
        self.naturalStatusImage = image;
    } else {
        self.traditionalStatusImage = image;
    }

    return image;
}


- (void)updateStatus {
    BOOL natural = [self isNaturalScrolling];

    self.statusItem.button.image =
        [self statusImageForNaturalScrolling:natural];
    self.statusItem.button.title = @"";

    self.statusItem.button.toolTip =
        natural
            ? @"Natural Scrolling"
            : @"Traditional Scrolling";

    self.naturalMenuItem.state =
        natural ? NSControlStateValueOn
                : NSControlStateValueOff;

    self.traditionalMenuItem.state =
        natural ? NSControlStateValueOff
                : NSControlStateValueOn;

    [self updateLoginItemStatus];
}


#pragma mark - Scroll actions

- (void)toggleScrolling:(id)sender {
    BOOL current = [self isNaturalScrolling];

    [self applyScrollSetting:!current];
    [self updateStatus];
}


- (void)setNaturalScrolling:(id)sender {
    [self applyScrollSetting:YES];
    [self updateStatus];
}


- (void)setTraditionalScrolling:(id)sender {
    [self applyScrollSetting:NO];
    [self updateStatus];
}


#pragma mark - Login item

- (void)updateLoginItemStatus {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];

        switch (service.status) {

            case SMAppServiceStatusEnabled:
                self.launchAtLoginMenuItem.state =
                    NSControlStateValueOn;

                self.launchAtLoginMenuItem.title =
                    @"Launch at Login";
                break;

            case SMAppServiceStatusRequiresApproval:
                self.launchAtLoginMenuItem.state =
                    NSControlStateValueMixed;

                self.launchAtLoginMenuItem.title =
                    @"Launch at Login (Approval Required)";
                break;

            default:
                self.launchAtLoginMenuItem.state =
                    NSControlStateValueOff;

                self.launchAtLoginMenuItem.title =
                    @"Launch at Login";
                break;
        }

    } else {
        self.launchAtLoginMenuItem.enabled = NO;
        self.launchAtLoginMenuItem.title =
            @"Launch at Login (Requires macOS 13+)";
    }
}


- (void)toggleLaunchAtLogin:(id)sender {
    if (@available(macOS 13.0, *)) {

        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;

        if (service.status == SMAppServiceStatusEnabled) {

            if (![service unregisterAndReturnError:&error]) {
                NSLog(@"Failed to disable Launch at Login: %@",
                      error);
            }

        } else {

            if (![service registerAndReturnError:&error]) {
                NSLog(@"Failed to enable Launch at Login: %@",
                      error);

                /*
                 If macOS requires explicit approval,
                 open the appropriate System Settings page.
                 */
                if (service.status ==
                    SMAppServiceStatusRequiresApproval) {

                    [SMAppService openSystemSettingsLoginItems];
                }
            }
        }

        [self updateLoginItemStatus];
    }
}


#pragma mark - Right-click menu

- (void)buildMenu {
    self.statusMenu = [[NSMenu alloc] init];


    self.naturalMenuItem =
        [[NSMenuItem alloc]
            initWithTitle:@"Natural Scrolling"
                   action:@selector(setNaturalScrolling:)
            keyEquivalent:@""];

    self.naturalMenuItem.target = self;

    [self.statusMenu addItem:self.naturalMenuItem];


    self.traditionalMenuItem =
        [[NSMenuItem alloc]
            initWithTitle:@"Traditional Scrolling"
                   action:@selector(setTraditionalScrolling:)
            keyEquivalent:@""];

    self.traditionalMenuItem.target = self;

    [self.statusMenu addItem:self.traditionalMenuItem];


    [self.statusMenu addItem:[NSMenuItem separatorItem]];



    self.launchAtLoginMenuItem =
        [[NSMenuItem alloc]
            initWithTitle:@"Launch at Login"
                   action:@selector(toggleLaunchAtLogin:)
            keyEquivalent:@""];

    self.launchAtLoginMenuItem.target = self;

    [self.statusMenu addItem:self.launchAtLoginMenuItem];


    [self.statusMenu addItem:[NSMenuItem separatorItem]];



    NSMenuItem *quitItem =
        [[NSMenuItem alloc]
            initWithTitle:@"Quit ScrollToggle"
                   action:@selector(quitApplication:)
            keyEquivalent:@"q"];

    quitItem.target = self;

    [self.statusMenu addItem:quitItem];
}


#pragma mark - Status bar mouse handling

- (void)statusItemClicked:(id)sender {
    NSEvent *event = [NSApp currentEvent];

    if (event.type == NSEventTypeRightMouseUp) {
        [self updateStatus];

        self.statusItem.menu = self.statusMenu;

        [self.statusItem.button performClick:nil];

        self.statusItem.menu = nil;
    } else {
        [self toggleScrolling:sender];
    }
}


#pragma mark - Quit

- (void)quitApplication:(id)sender {
    [NSApp terminate:nil];
}


#pragma mark - App lifecycle

- (void)applicationDidFinishLaunching:
    (NSNotification *)notification {

    self.statusItem =
        [[NSStatusBar systemStatusBar]
            statusItemWithLength:NSVariableStatusItemLength];

    self.statusItem.button.target = self;

    self.statusItem.button.action =
        @selector(statusItemClicked:);

    /*
     Tell the status item to send both left and right
     mouse-up events to our action.
    */
    [self.statusItem.button
        sendActionOn:
            NSEventMaskLeftMouseUp |
            NSEventMaskRightMouseUp];

    [self buildMenu];

    [self updateStatus];
}

@end


int main(int argc, const char *argv[]) {
    @autoreleasepool {

        NSApplication *app =
            [NSApplication sharedApplication];

        AppDelegate *delegate =
            [[AppDelegate alloc] init];

        app.delegate = delegate;

        [app setActivationPolicy:
             NSApplicationActivationPolicyAccessory];

        [app run];
    }

    return 0;
}
