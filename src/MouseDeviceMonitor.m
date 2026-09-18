#import "MouseDeviceMonitor.h"

#import "DeviceActivityRouting.h"
#import "DeviceProfile.h"
#import "MouseNudgeFilter.h"

#import <IOKit/hid/IOHIDDevice.h>
#import <IOKit/hid/IOHIDDeviceKeys.h>
#import <IOKit/hid/IOHIDElement.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDUsageTables.h>
#import <IOKit/hid/IOHIDValue.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <mach/mach_time.h>

static NSString * const STMouseMonitorErrorDomain =
    @"com.ali.scrolltoggle.MouseDeviceMonitor";

@class STDeviceActivityContext;

@interface MouseDeviceMonitor ()
@property (strong) NSMutableSet<NSValue *> *observedDeviceKeys;
@property (strong) NSMutableDictionary<NSValue *, NSString *> *deviceIdentifiers;
@property (strong) NSMutableDictionary<NSString *, NSNumber *> *identifierCounts;
@property (strong) NSMutableDictionary<NSString *, MouseDeviceDescriptor *> *descriptors;
@property (strong) NSMapTable<id, STDeviceActivityContext *> *activityContexts;
@property (copy, nullable) NSString *lastActivityIdentifier;
@property uint64_t activityGeneration;
@property uint64_t nudgeWindowTicks;
@property BOOL inputMonitoringAvailable;
@property BOOL managerOpen;
@property BOOL starting;

- (void)registerDevice:(IOHIDDeviceRef)device notifyDelegate:(BOOL)notify;
- (void)unregisterDevice:(IOHIDDeviceRef)device notifyDelegate:(BOOL)notify;
- (void)handleMouseValue:(IOHIDValueRef)value device:(IOHIDDeviceRef)device;
- (void)handleInputReportForDevice:(IOHIDDeviceRef)device;
@end

@interface STDeviceActivityContext : NSObject {
@public
    NSString *_identifier;
    STActivityDeviceKind _kind;
    STMouseNudgeState _nudgeState;
}
@end

@implementation STDeviceActivityContext
@end

@implementation MouseDeviceDescriptor

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                         transport:(NSString *)transport
                          vendorID:(NSInteger)vendorID
                         productID:(NSInteger)productID {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _displayName = [displayName copy];
        _transport = [transport copy];
        _vendorID = vendorID;
        _productID = productID;
    }
    return self;
}

@end

@implementation MouseDeviceMonitor

static void STDeviceMatched(void *context,
                            IOReturn result,
                            void *sender,
                            IOHIDDeviceRef device) {
    (void)sender;
    if (result != kIOReturnSuccess) {
        return;
    }
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    [monitor registerDevice:device notifyDelegate:!monitor.starting];
}

static void STDeviceRemoved(void *context,
                            IOReturn result,
                            void *sender,
                            IOHIDDeviceRef device) {
    (void)sender;
    if (result != kIOReturnSuccess) {
        return;
    }
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    [monitor unregisterDevice:device notifyDelegate:!monitor.starting];
}

static void STMouseInputValue(void *context,
                              IOReturn result,
                              void *sender,
                              IOHIDValueRef value) {
    (void)sender;
    if (result != kIOReturnSuccess) {
        return;
    }
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    IOHIDDeviceRef device = IOHIDElementGetDevice(element);
    [monitor handleMouseValue:value device:device];
}

static void STTrackpadInputReport(void *context,
                                  IOReturn result,
                                  void *sender,
                                  IOHIDReportType type,
                                  uint32_t reportID,
                                  uint8_t *report,
                                  CFIndex reportLength) {
    (void)type;
    (void)reportID;
    (void)report;
    (void)reportLength;
    if (result != kIOReturnSuccess) {
        return;
    }
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    IOHIDDeviceRef device = (IOHIDDeviceRef)sender;
    [monitor handleInputReportForDevice:device];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observedDeviceKeys = [NSMutableSet set];
        _deviceIdentifiers = [NSMutableDictionary dictionary];
        _identifierCounts = [NSMutableDictionary dictionary];
        _descriptors = [NSMutableDictionary dictionary];
        _activityContexts =
            [NSMapTable mapTableWithKeyOptions:
                NSPointerFunctionsStrongMemory |
                NSPointerFunctionsObjectPointerPersonality
                                  valueOptions:NSPointerFunctionsStrongMemory];
        _activityGeneration = 1;

        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        _nudgeWindowTicks =
            (UINT64_C(100000000) * timebase.denom) / timebase.numer;
    }
    return self;
}

- (NSArray<MouseDeviceDescriptor *> *)startMonitoringWithError:(NSError **)error {
    if (_manager) {
        return self.descriptors.allValues;
    }

    self.starting = YES;
    IOHIDAccessType access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent);
    if (access == kIOHIDAccessTypeUnknown) {
        BOOL granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);
        access = granted ? kIOHIDAccessTypeGranted
                         : IOHIDCheckAccess(kIOHIDRequestTypeListenEvent);
    }
    self.inputMonitoringAvailable = access == kIOHIDAccessTypeGranted;

    IOHIDManagerRef manager =
        IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) {
        self.starting = NO;
        if (error) {
            *error = [NSError errorWithDomain:STMouseMonitorErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Unable to create the HID device manager."}];
        }
        return nil;
    }
    _manager = manager;

    NSDictionary *matching = @{
        @kIOHIDPrimaryUsagePageKey: @(kHIDPage_GenericDesktop),
        @kIOHIDPrimaryUsageKey: @(kHIDUsage_GD_Mouse)
    };
    IOHIDManagerSetDeviceMatching(_manager, (__bridge CFDictionaryRef)matching);
    IOHIDManagerRegisterDeviceMatchingCallback(_manager, STDeviceMatched,
                                                (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, STDeviceRemoved,
                                               (__bridge void *)self);

    NSArray *inputMatching = @[
        @{@kIOHIDElementUsagePageKey: @(kHIDPage_GenericDesktop),
          @kIOHIDElementUsageKey: @(kHIDUsage_GD_X)},
        @{@kIOHIDElementUsagePageKey: @(kHIDPage_GenericDesktop),
          @kIOHIDElementUsageKey: @(kHIDUsage_GD_Y)},
        @{@kIOHIDElementUsagePageKey: @(kHIDPage_GenericDesktop),
          @kIOHIDElementUsageKey: @(kHIDUsage_GD_Wheel)},
        @{@kIOHIDElementUsagePageKey: @(kHIDPage_Consumer),
          @kIOHIDElementUsageKey: @(kHIDUsage_Csmr_ACPan)},
        @{@kIOHIDElementUsagePageKey: @(kHIDPage_Button)}
    ];
    IOHIDManagerSetInputValueMatchingMultiple(
        _manager, (__bridge CFArrayRef)inputMatching);
    IOHIDManagerRegisterInputValueCallback(
        _manager, STMouseInputValue, (__bridge void *)self);
    IOHIDManagerRegisterInputReportCallback(
        _manager, STTrackpadInputReport, (__bridge void *)self);

    // Build the routing map before reports can be delivered.
    CFSetRef deviceSet = IOHIDManagerCopyDevices(_manager);
    if (deviceSet) {
        for (id object in (__bridge NSSet *)deviceSet) {
            IOHIDDeviceRef device = (__bridge IOHIDDeviceRef)object;
            [self registerDevice:device notifyDelegate:NO];
        }
        CFRelease(deviceSet);
    }

    IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(),
                                    kCFRunLoopCommonModes);

    if (self.inputMonitoringAvailable) {
        IOReturn openResult =
            IOHIDManagerOpen(_manager, kIOHIDOptionsTypeNone);
        if (openResult == kIOReturnSuccess) {
            self.managerOpen = YES;
        } else {
            self.inputMonitoringAvailable = NO;
            [self.activityContexts removeAllObjects];
            NSLog(@"Unable to open HID devices for activity monitoring: 0x%x",
                  openResult);
        }
    }

    self.starting = NO;
    return [self.descriptors.allValues sortedArrayUsingComparator:
        ^NSComparisonResult(MouseDeviceDescriptor *left,
                            MouseDeviceDescriptor *right) {
            return [left.identifier compare:right.identifier];
        }];
}

- (void)stopMonitoring {
    if (!_manager) {
        return;
    }

    IOHIDManagerUnscheduleFromRunLoop(_manager, CFRunLoopGetMain(),
                                      kCFRunLoopCommonModes);
    if (self.managerOpen) {
        IOHIDManagerClose(_manager, kIOHIDOptionsTypeNone);
    }
    CFRelease(_manager);
    _manager = NULL;
    self.managerOpen = NO;
    self.inputMonitoringAvailable = NO;
    self.lastActivityIdentifier = nil;
    [self.observedDeviceKeys removeAllObjects];
    [self.deviceIdentifiers removeAllObjects];
    [self.identifierCounts removeAllObjects];
    [self.descriptors removeAllObjects];
    [self.activityContexts removeAllObjects];
}

- (void)dealloc {
    [self stopMonitoring];
}

- (void)registerDevice:(IOHIDDeviceRef)device notifyDelegate:(BOOL)notify {
    NSValue *deviceKey = [NSValue valueWithPointer:device];
    if ([self.observedDeviceKeys containsObject:deviceKey]) {
        return;
    }
    [self.observedDeviceKeys addObject:deviceKey];

    if ([self hasTrackpadUsagePair:device]) {
        NSNumber *builtIn = [self numberProperty:kIOHIDBuiltInKey device:device];
        if (builtIn.boolValue && self.inputMonitoringAvailable) {
            [self registerTrackpadActivityForDevice:device];
        }
        return;
    }

    MouseDeviceDescriptor *descriptor = [self descriptorForDevice:device];
    if (!descriptor) {
        return;
    }

    if (![self hasStrictMouseUsagePairs:device]) {
        [self.delegate mouseDeviceMonitor:self
            didRejectCompositeDeviceWithIdentifier:descriptor.identifier];
        return;
    }

    NSString *identifier = descriptor.identifier;
    NSInteger oldCount = self.identifierCounts[identifier].integerValue;
    self.deviceIdentifiers[deviceKey] = identifier;
    self.identifierCounts[identifier] = @(oldCount + 1);
    self.descriptors[identifier] = descriptor;

    if (self.inputMonitoringAvailable) {
        [self registerMouseActivityForDevice:device identifier:identifier];
    }
    if (notify && oldCount == 0) {
        [self.delegate mouseDeviceMonitor:self didConnectDevice:descriptor];
    }
}

- (void)unregisterDevice:(IOHIDDeviceRef)device notifyDelegate:(BOOL)notify {
    NSValue *deviceKey = [NSValue valueWithPointer:device];
    STDeviceActivityContext *activity =
        [self.activityContexts objectForKey:(__bridge id)device];
    BOOL removedTrackpad =
        activity && activity->_kind == STActivityDeviceKindTrackpad;
    [self.observedDeviceKeys removeObject:deviceKey];
    [self unregisterActivityForDevice:device];

    NSString *identifier = self.deviceIdentifiers[deviceKey];
    if (!identifier) {
        if (removedTrackpad && [self.lastActivityIdentifier
                isEqualToString:STTrackpadProfileIdentifier]) {
            self.lastActivityIdentifier = nil;
        }
        return;
    }

    [self.deviceIdentifiers removeObjectForKey:deviceKey];
    NSInteger newCount = self.identifierCounts[identifier].integerValue - 1;
    if (newCount > 0) {
        self.identifierCounts[identifier] = @(newCount);
        return;
    }

    [self.identifierCounts removeObjectForKey:identifier];
    [self.descriptors removeObjectForKey:identifier];
    if ([self.lastActivityIdentifier isEqualToString:identifier]) {
        self.lastActivityIdentifier = nil;
    }
    if (notify) {
        [self.delegate mouseDeviceMonitor:self
               didDisconnectDeviceWithIdentifier:identifier];
    }
}

- (void)registerMouseActivityForDevice:(IOHIDDeviceRef)device
                             identifier:(NSString *)identifier {
    id deviceKey = (__bridge id)device;
    if ([self.activityContexts objectForKey:deviceKey]) {
        return;
    }

    STDeviceActivityContext *context = [[STDeviceActivityContext alloc] init];
    context->_identifier = [identifier copy];
    context->_kind = STActivityDeviceKindMouse;
    STMouseNudgeReset(&context->_nudgeState, self.activityGeneration);
    [self.activityContexts setObject:context forKey:deviceKey];
}

- (void)registerTrackpadActivityForDevice:(IOHIDDeviceRef)device {
    id deviceKey = (__bridge id)device;
    if ([self.activityContexts objectForKey:deviceKey]) {
        return;
    }

    STDeviceActivityContext *context = [[STDeviceActivityContext alloc] init];
    context->_identifier = STTrackpadProfileIdentifier;
    context->_kind = STActivityDeviceKindTrackpad;
    [self.activityContexts setObject:context forKey:deviceKey];
}

- (void)unregisterActivityForDevice:(IOHIDDeviceRef)device {
    [self.activityContexts removeObjectForKey:(__bridge id)device];
}

- (void)handleMouseValue:(IOHIDValueRef)value
                  device:(IOHIDDeviceRef)device {
    STDeviceActivityContext *context =
        [self.activityContexts objectForKey:(__bridge id)device];
    if (!context || !STActivityRoutesInputValue(context->_kind) ||
        [self.lastActivityIdentifier isEqualToString:context->_identifier]) {
        return;
    }

    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex integerValue = IOHIDValueGetIntegerValue(value);

    if ((usagePage == kHIDPage_Button && integerValue != 0) ||
        (usagePage == kHIDPage_GenericDesktop &&
         usage == kHIDUsage_GD_Wheel && integerValue != 0) ||
        (usagePage == kHIDPage_Consumer &&
         usage == kHIDUsage_Csmr_ACPan && integerValue != 0)) {
        [self activateIdentifier:context->_identifier];
        return;
    }

    if (usagePage != kHIDPage_GenericDesktop ||
        (usage != kHIDUsage_GD_X && usage != kHIDUsage_GD_Y)) {
        return;
    }

    if (STMouseNudgeRecordMovement(&context->_nudgeState,
                                   integerValue,
                                   IOHIDValueGetTimeStamp(value),
                                   self.nudgeWindowTicks,
                                   self.activityGeneration)) {
        [self activateIdentifier:context->_identifier];
    }
}

- (void)handleInputReportForDevice:(IOHIDDeviceRef)device {
    STDeviceActivityContext *context =
        [self.activityContexts objectForKey:(__bridge id)device];
    if (!context || !STActivityRoutesInputReport(context->_kind)) {
        return;
    }
    self.activityGeneration++;
    if ([self.lastActivityIdentifier isEqualToString:context->_identifier]) {
        return;
    }
    self.lastActivityIdentifier = context->_identifier;
    [self.delegate mouseDeviceMonitor:self
        didReceiveActivityForProfileIdentifier:context->_identifier];
}

- (void)activateIdentifier:(NSString *)identifier {
    if ([self.lastActivityIdentifier isEqualToString:identifier]) {
        return;
    }
    self.activityGeneration++;
    self.lastActivityIdentifier = identifier;
    [self.delegate mouseDeviceMonitor:self
        didReceiveActivityForProfileIdentifier:identifier];
}

- (BOOL)hasTrackpadUsagePair:(IOHIDDeviceRef)device {
    id value = [self objectProperty:kIOHIDDeviceUsagePairsKey device:device];
    if (![value isKindOfClass:[NSArray class]]) {
        return NO;
    }
    for (id object in (NSArray *)value) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *pair = object;
        NSNumber *usagePage = pair[@kIOHIDDeviceUsagePageKey];
        NSNumber *usage = pair[@kIOHIDDeviceUsageKey];
        if (usagePage.integerValue == kHIDPage_Digitizer &&
            usage.integerValue == kHIDUsage_Dig_TouchPad) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)hasStrictMouseUsagePairs:(IOHIDDeviceRef)device {
    id value = [self objectProperty:kIOHIDDeviceUsagePairsKey device:device];
    if (![value isKindOfClass:[NSArray class]]) {
        return NO;
    }

    BOOL hasMouse = NO;
    BOOL hasPointer = NO;
    for (id object in (NSArray *)value) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *pair = object;
        NSNumber *usagePage = pair[@kIOHIDDeviceUsagePageKey];
        NSNumber *usage = pair[@kIOHIDDeviceUsageKey];
        if (![usagePage isKindOfClass:[NSNumber class]] ||
            ![usage isKindOfClass:[NSNumber class]] ||
            usagePage.integerValue != kHIDPage_GenericDesktop) {
            continue;
        }

        if (usage.integerValue == kHIDUsage_GD_Keyboard ||
            usage.integerValue == kHIDUsage_GD_Keypad) {
            return NO;
        }
        if (usage.integerValue == kHIDUsage_GD_Mouse) {
            hasMouse = YES;
        } else if (usage.integerValue == kHIDUsage_GD_Pointer) {
            hasPointer = YES;
        }
    }

    return hasMouse && hasPointer;
}

- (MouseDeviceDescriptor *)descriptorForDevice:(IOHIDDeviceRef)device {
    NSNumber *usagePage =
        [self numberProperty:kIOHIDPrimaryUsagePageKey device:device];
    NSNumber *usage =
        [self numberProperty:kIOHIDPrimaryUsageKey device:device];
    if (usagePage.integerValue != kHIDPage_GenericDesktop ||
        usage.integerValue != kHIDUsage_GD_Mouse) {
        return nil;
    }

    NSNumber *builtIn = [self numberProperty:kIOHIDBuiltInKey device:device];
    if (builtIn.boolValue) {
        return nil;
    }

    NSString *rawTransport = [self stringProperty:kIOHIDTransportKey device:device];
    if ([rawTransport caseInsensitiveCompare:@kIOHIDTransportVirtualValue] ==
        NSOrderedSame) {
        return nil;
    }

    NSInteger vendorID =
        [self numberProperty:kIOHIDVendorIDKey device:device].integerValue;
    NSInteger productID =
        [self numberProperty:kIOHIDProductIDKey device:device].integerValue;
    NSString *product = [self stringProperty:kIOHIDProductKey device:device];
    NSString *manufacturer =
        [self stringProperty:kIOHIDManufacturerKey device:device];
    NSString *serial =
        [self stringProperty:kIOHIDSerialNumberKey device:device];
    id uniqueID = [self objectProperty:kIOHIDUniqueIDKey device:device];
    NSNumber *locationID =
        [self numberProperty:kIOHIDLocationIDKey device:device];

    NSString *displayName = product.length > 0 ? product : nil;
    if (!displayName && manufacturer.length > 0) {
        displayName = [NSString stringWithFormat:@"%@ Mouse", manufacturer];
    }
    if (!displayName) {
        displayName = @"Unknown Mouse";
    }

    NSString *transport = [self displayTransportForRawTransport:rawTransport];
    NSString *identifier = nil;
    if (serial.length > 0) {
        identifier = [NSString stringWithFormat:@"serial|%ld|%ld|%@",
                      (long)vendorID, (long)productID, serial];
    } else if ([uniqueID isKindOfClass:[NSString class]] ||
               [uniqueID isKindOfClass:[NSNumber class]]) {
        identifier = [NSString stringWithFormat:@"unique|%ld|%ld|%@",
                      (long)vendorID, (long)productID, uniqueID];
    } else if (locationID) {
        identifier = [NSString stringWithFormat:@"location|%ld|%ld|%@|%@",
                      (long)vendorID, (long)productID,
                      rawTransport ?: @"unknown", locationID];
    } else {
        identifier = [NSString stringWithFormat:@"model|%ld|%ld|%@|%@",
                      (long)vendorID, (long)productID,
                      rawTransport ?: @"unknown", displayName];
    }

    return [[MouseDeviceDescriptor alloc]
        initWithIdentifier:identifier
               displayName:displayName
                 transport:transport
                  vendorID:vendorID
                 productID:productID];
}

- (id)objectProperty:(const char *)key device:(IOHIDDeviceRef)device {
    CFStringRef propertyKey = CFStringCreateWithCString(
        kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    CFTypeRef value = IOHIDDeviceGetProperty(device, propertyKey);
    CFRelease(propertyKey);
    return (__bridge id)value;
}

- (NSString *)stringProperty:(const char *)key device:(IOHIDDeviceRef)device {
    id value = [self objectProperty:key device:device];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSNumber *)numberProperty:(const char *)key device:(IOHIDDeviceRef)device {
    id value = [self objectProperty:key device:device];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

- (NSString *)displayTransportForRawTransport:(NSString *)rawTransport {
    if ((rawTransport &&
         [rawTransport rangeOfString:@"Bluetooth"
                             options:NSCaseInsensitiveSearch].location != NSNotFound) ||
        [rawTransport isEqualToString:@kIOHIDTransportBTAACPValue]) {
        return @"Bluetooth";
    }
    return @"Wired";
}

@end
