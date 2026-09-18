#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

#import "DeviceStore.h"
#import "DeviceSelection.h"
#import "MouseDeviceMonitor.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, MouseDeviceMonitorDelegate>

@property (strong) NSStatusItem *statusItem;
@property (strong) NSMenu *statusMenu;

@property (strong) NSImage *naturalStatusImage;
@property (strong) NSImage *traditionalStatusImage;

@property (strong) NSMenuItem *launchAtLoginMenuItem;

@property (strong) DeviceStore *deviceStore;
@property (strong) MouseDeviceMonitor *mouseMonitor;
@property (strong) NSMutableDictionary<NSString *, MouseDeviceDescriptor *> *connectedDevices;
@property (strong) NSMutableDictionary<NSString *, NSDate *> *connectedAt;
@property (strong) NSMutableDictionary<NSString *, NSNumber *> *lastUsedOrder;
@property uint64_t usageSequence;
@property (copy) NSString *activeProfileIdentifier;

@end


@implementation AppDelegate

#pragma mark - Scroll setting

- (BOOL)isNaturalScrolling {
    CFPropertyListRef value = CFPreferencesCopyValue(
        CFSTR("com.apple.swipescrolldirection"),
        kCFPreferencesAnyApplication,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost);
    if (!value) {
        return YES;
    }
    BOOL natural = [(__bridge id)value boolValue];
    CFRelease(value);
    return natural;
}


- (void)applyScrollSetting:(BOOL)natural {
    CFPreferencesSetValue(
        CFSTR("com.apple.swipescrolldirection"),
        natural ? kCFBooleanTrue : kCFBooleanFalse,
        kCFPreferencesAnyApplication,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost);
    if (!CFPreferencesSynchronize(kCFPreferencesAnyApplication,
                                  kCFPreferencesCurrentUser,
                                  kCFPreferencesAnyHost)) {
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
        self.mouseMonitor && !self.mouseMonitor.inputMonitoringAvailable
            ? @"Input Monitoring Required"
            : (natural ? @"Natural Scrolling" : @"Traditional Scrolling");

    [self updateLoginItemStatus];
}


#pragma mark - Scroll actions

- (DeviceProfile *)activeProfile {
    DeviceProfile *profile =
        [self.deviceStore profileForIdentifier:self.activeProfileIdentifier];
    if (!profile) {
        profile = [self.deviceStore
            ensureTrackpadProfileWithNaturalScrolling:YES];
        self.activeProfileIdentifier = profile.identifier;
    }
    return profile;
}

- (void)applyActiveProfile {
    DeviceProfile *profile = [self activeProfile];
    if ([self isNaturalScrolling] != profile.naturalScrolling) {
        [self applyScrollSetting:profile.naturalScrolling];
    }
    [self updateStatus];
}

- (void)selectActiveProfile {
    self.activeProfileIdentifier =
        STSelectActiveProfileIdentifier(self.connectedAt);
}

- (void)selectMostRecentlyUsedConnectedProfile {
    self.activeProfileIdentifier =
        STSelectMostRecentlyUsedProfileIdentifier(
            [NSSet setWithArray:self.connectedDevices.allKeys],
            self.lastUsedOrder);
}

- (void)toggleActiveProfilePreference:(id)sender {
    BOOL natural = ![self isNaturalScrolling];
    [self.deviceStore setNaturalScrolling:natural
                            forIdentifier:self.activeProfileIdentifier];
    [self applyScrollSetting:natural];
    [self updateStatus];
    [self rebuildStatusMenu];
}

- (void)toggleDeviceProfilePreference:(NSMenuItem *)sender {
    NSString *identifier = sender.representedObject;
    DeviceProfile *profile = [self.deviceStore profileForIdentifier:identifier];
    if (!profile) {
        return;
    }

    [self.deviceStore setNaturalScrolling:!profile.naturalScrolling
                            forIdentifier:identifier];
    if ([identifier isEqualToString:self.activeProfileIdentifier]) {
        [self applyActiveProfile];
    }
    [self rebuildStatusMenu];
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
    [self rebuildStatusMenu];
}

- (BOOL)isProfileConnected:(DeviceProfile *)profile {
    if ([profile.identifier isEqualToString:STTrackpadProfileIdentifier]) {
        return YES;
    }
    return self.connectedDevices[profile.identifier] != nil;
}

- (NSMenuItem *)sectionHeaderWithTitle:(NSString *)title {
    NSMenuItem *item =
        [[NSMenuItem alloc]
            initWithTitle:title
                   action:nil
            keyEquivalent:@""];
    item.enabled = NO;
    return item;
}

- (NSMenuItem *)menuItemForDeviceProfile:(DeviceProfile *)profile {
    BOOL fallback =
        [profile.identifier isEqualToString:STTrackpadProfileIdentifier];
    BOOL active =
        [profile.identifier isEqualToString:self.activeProfileIdentifier];

    NSString *title = profile.displayName;
    if (!fallback) {
        title = [title stringByAppendingFormat:@" — %@", profile.transport];
    }
    if (active) {
        title = [title stringByAppendingString:@" • Active"];
    }

    NSMenuItem *deviceItem =
        [[NSMenuItem alloc]
            initWithTitle:title
                   action:nil
            keyEquivalent:@""];
    NSMenu *settingsMenu = [[NSMenu alloc] initWithTitle:profile.displayName];
    NSMenuItem *naturalItem =
        [[NSMenuItem alloc]
            initWithTitle:@"Natural Scrolling"
                   action:@selector(toggleDeviceProfilePreference:)
            keyEquivalent:@""];
    naturalItem.target = self;
    naturalItem.representedObject = profile.identifier;
    naturalItem.state = profile.naturalScrolling ? NSControlStateValueOn
                                                  : NSControlStateValueOff;
    [settingsMenu addItem:naturalItem];
    deviceItem.submenu = settingsMenu;
    return deviceItem;
}

- (void)rebuildStatusMenu {
    [self.statusMenu removeAllItems];

    NSMutableArray<DeviceProfile *> *connectedProfiles = [NSMutableArray array];
    NSMutableArray<DeviceProfile *> *disconnectedProfiles = [NSMutableArray array];
    for (DeviceProfile *profile in [self.deviceStore allProfiles]) {
        if ([self isProfileConnected:profile]) {
            [connectedProfiles addObject:profile];
        } else {
            [disconnectedProfiles addObject:profile];
        }
    }

    [connectedProfiles sortUsingComparator:
        ^NSComparisonResult(DeviceProfile *left, DeviceProfile *right) {
            BOOL leftActive =
                [left.identifier isEqualToString:self.activeProfileIdentifier];
            BOOL rightActive =
                [right.identifier isEqualToString:self.activeProfileIdentifier];
            if (leftActive != rightActive) {
                return leftActive ? NSOrderedAscending : NSOrderedDescending;
            }

            BOOL leftTrackpad =
                [left.identifier isEqualToString:STTrackpadProfileIdentifier];
            BOOL rightTrackpad =
                [right.identifier isEqualToString:STTrackpadProfileIdentifier];
            if (leftTrackpad != rightTrackpad) {
                return leftTrackpad ? NSOrderedAscending : NSOrderedDescending;
            }

            NSDate *leftDate = self.connectedAt[left.identifier] ?: left.lastSeenAt;
            NSDate *rightDate = self.connectedAt[right.identifier] ?: right.lastSeenAt;
            NSComparisonResult dateResult = [rightDate compare:leftDate];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
            return [left.displayName localizedCaseInsensitiveCompare:right.displayName];
        }];

    [disconnectedProfiles sortUsingComparator:
        ^NSComparisonResult(DeviceProfile *left, DeviceProfile *right) {
            NSComparisonResult dateResult = [right.lastSeenAt compare:left.lastSeenAt];
            if (dateResult != NSOrderedSame) {
                return dateResult;
            }
            return [left.displayName localizedCaseInsensitiveCompare:right.displayName];
        }];

    [self.statusMenu addItem:[self sectionHeaderWithTitle:@"Connected"]];
    for (DeviceProfile *profile in connectedProfiles) {
        [self.statusMenu addItem:[self menuItemForDeviceProfile:profile]];
    }

    if (disconnectedProfiles.count > 0) {
        [self.statusMenu addItem:[NSMenuItem separatorItem]];
        [self.statusMenu addItem:[self sectionHeaderWithTitle:@"Not Connected"]];
        for (DeviceProfile *profile in disconnectedProfiles) {
            [self.statusMenu addItem:[self menuItemForDeviceProfile:profile]];
        }
    }

    if (self.mouseMonitor &&
        !self.mouseMonitor.inputMonitoringAvailable) {
        [self.statusMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *permissionItem =
            [[NSMenuItem alloc]
                initWithTitle:@"Input Monitoring Required…"
                       action:@selector(openInputMonitoringSettings:)
                keyEquivalent:@""];
        permissionItem.target = self;
        [self.statusMenu addItem:permissionItem];
    }

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
    [self updateLoginItemStatus];
}

- (void)openInputMonitoringSettings:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Input Monitoring Required";
    alert.informativeText =
        @"Enable ScrollToggle in Privacy & Security → Input Monitoring, "
         "then quit and reopen ScrollToggle.";
    [alert addButtonWithTitle:@"Open Settings"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSURL *url = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


#pragma mark - Status bar mouse handling

- (void)statusItemClicked:(id)sender {
    NSEvent *event = [NSApp currentEvent];

    if (event.type == NSEventTypeRightMouseUp) {
        [self updateStatus];
        [self rebuildStatusMenu];

        self.statusItem.menu = self.statusMenu;

        [self.statusItem.button performClick:nil];

        self.statusItem.menu = nil;
    } else {
        [self toggleActiveProfilePreference:sender];
    }
}


#pragma mark - Mouse devices

- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
          didConnectDevice:(MouseDeviceDescriptor *)device {
    NSDate *now = [NSDate date];
    [self.deviceStore upsertMouseWithIdentifier:device.identifier
                                    displayName:device.displayName
                                      transport:device.transport
                                       vendorID:device.vendorID
                                      productID:device.productID
                                           seen:now];
    self.connectedDevices[device.identifier] = device;
    self.connectedAt[device.identifier] = now;
    [self rebuildStatusMenu];
}

- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
        didDisconnectDeviceWithIdentifier:(NSString *)identifier {
    BOOL wasActive =
        [self.activeProfileIdentifier isEqualToString:identifier];
    [self.connectedDevices removeObjectForKey:identifier];
    [self.connectedAt removeObjectForKey:identifier];
    [self.lastUsedOrder removeObjectForKey:identifier];
    if (wasActive) {
        [self selectMostRecentlyUsedConnectedProfile];
        [self applyActiveProfile];
    }
    [self rebuildStatusMenu];
}

- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
        didReceiveActivityForProfileIdentifier:(NSString *)identifier {
    if (![identifier isEqualToString:STTrackpadProfileIdentifier] &&
        !self.connectedDevices[identifier]) {
        return;
    }

    self.usageSequence++;
    self.lastUsedOrder[identifier] = @(self.usageSequence);
    if ([self.activeProfileIdentifier isEqualToString:identifier]) {
        return;
    }

    self.activeProfileIdentifier = identifier;
    [self applyActiveProfile];
    [self rebuildStatusMenu];
}

- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
        didRejectCompositeDeviceWithIdentifier:(NSString *)identifier {
    if (![self.deviceStore removeProfileForIdentifier:identifier]) {
        return;
    }

    [self.connectedDevices removeObjectForKey:identifier];
    [self.connectedAt removeObjectForKey:identifier];
    [self.lastUsedOrder removeObjectForKey:identifier];
    if ([self.activeProfileIdentifier isEqualToString:identifier]) {
        [self selectMostRecentlyUsedConnectedProfile];
        [self applyActiveProfile];
    }
    [self rebuildStatusMenu];
}


#pragma mark - Quit

- (void)quitApplication:(id)sender {
    [NSApp terminate:nil];
}


#pragma mark - App lifecycle

- (void)applicationDidFinishLaunching:
    (NSNotification *)notification {

    self.deviceStore = [[DeviceStore alloc]
        initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    [self.deviceStore
        ensureTrackpadProfileWithNaturalScrolling:YES];
    self.connectedDevices = [NSMutableDictionary dictionary];
    self.connectedAt = [NSMutableDictionary dictionary];
    self.lastUsedOrder = [NSMutableDictionary dictionary];
    self.activeProfileIdentifier = STTrackpadProfileIdentifier;

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

    self.mouseMonitor = [[MouseDeviceMonitor alloc] init];
    self.mouseMonitor.delegate = self;
    NSError *monitorError = nil;
    NSArray<MouseDeviceDescriptor *> *initialDevices =
        [self.mouseMonitor startMonitoringWithError:&monitorError];
    if (!initialDevices) {
        NSLog(@"Unable to monitor mouse devices: %@", monitorError);
    }

    NSDate *now = [NSDate date];
    for (MouseDeviceDescriptor *device in initialDevices) {
        DeviceProfile *existing =
            [self.deviceStore profileForIdentifier:device.identifier];
        self.connectedDevices[device.identifier] = device;
        self.connectedAt[device.identifier] =
            existing.lastSeenAt ?: [NSDate distantPast];
    }
    [self selectActiveProfile];

    for (MouseDeviceDescriptor *device in initialDevices) {
        [self.deviceStore upsertMouseWithIdentifier:device.identifier
                                        displayName:device.displayName
                                          transport:device.transport
                                           vendorID:device.vendorID
                                          productID:device.productID
                                               seen:now];
    }

    [self applyActiveProfile];
    [self rebuildStatusMenu];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.mouseMonitor stopMonitoring];
}

@end


int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
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
