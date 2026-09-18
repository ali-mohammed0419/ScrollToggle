#import "MouseDeviceMonitor.h"

#import <IOKit/hid/IOHIDDevice.h>
#import <IOKit/hid/IOHIDDeviceKeys.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDUsageTables.h>

static NSString * const STMouseMonitorErrorDomain = @"com.ali.scrolltoggle.MouseDeviceMonitor";

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

@interface MouseDeviceMonitor ()
@property (strong) NSMutableSet<NSValue *> *observedDeviceKeys;
@property (strong) NSMutableDictionary<NSValue *, NSString *> *deviceIdentifiers;
@property (strong) NSMutableDictionary<NSString *, NSNumber *> *identifierCounts;
@property (strong) NSMutableDictionary<NSString *, MouseDeviceDescriptor *> *descriptors;
@property BOOL starting;
@end

@implementation MouseDeviceMonitor

static void STDeviceMatched(void *context,
                            IOReturn result,
                            void *sender,
                            IOHIDDeviceRef device) {
    (void)result;
    (void)sender;
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    [monitor registerDevice:device notifyDelegate:!monitor.starting];
}

static void STDeviceRemoved(void *context,
                            IOReturn result,
                            void *sender,
                            IOHIDDeviceRef device) {
    (void)result;
    (void)sender;
    MouseDeviceMonitor *monitor = (__bridge MouseDeviceMonitor *)context;
    [monitor unregisterDevice:device notifyDelegate:!monitor.starting];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observedDeviceKeys = [NSMutableSet set];
        _deviceIdentifiers = [NSMutableDictionary dictionary];
        _identifierCounts = [NSMutableDictionary dictionary];
        _descriptors = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<MouseDeviceDescriptor *> *)startMonitoringWithError:(NSError **)error {
    if (_manager) {
        return self.descriptors.allValues;
    }

    self.starting = YES;
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
    IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(),
                                    kCFRunLoopCommonModes);

    CFSetRef deviceSet = IOHIDManagerCopyDevices(_manager);
    if (deviceSet) {
        for (id object in (__bridge NSSet *)deviceSet) {
            IOHIDDeviceRef device = (__bridge IOHIDDeviceRef)object;
            [self registerDevice:device notifyDelegate:NO];
        }
        CFRelease(deviceSet);
    }

    self.starting = NO;
    return [self.descriptors.allValues sortedArrayUsingComparator:
        ^NSComparisonResult(MouseDeviceDescriptor *left, MouseDeviceDescriptor *right) {
            return [left.identifier compare:right.identifier];
        }];
}

- (void)stopMonitoring {
    if (!_manager) {
        return;
    }
    IOHIDManagerUnscheduleFromRunLoop(_manager, CFRunLoopGetMain(),
                                      kCFRunLoopCommonModes);
    CFRelease(_manager);
    _manager = NULL;
    [self.observedDeviceKeys removeAllObjects];
    [self.deviceIdentifiers removeAllObjects];
    [self.identifierCounts removeAllObjects];
    [self.descriptors removeAllObjects];
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

    if (notify && oldCount == 0) {
        [self.delegate mouseDeviceMonitor:self didConnectDevice:descriptor];
    }
}

- (void)unregisterDevice:(IOHIDDeviceRef)device notifyDelegate:(BOOL)notify {
    NSValue *deviceKey = [NSValue valueWithPointer:device];
    [self.observedDeviceKeys removeObject:deviceKey];
    NSString *identifier = self.deviceIdentifiers[deviceKey];
    if (!identifier) {
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
    if (notify) {
        [self.delegate mouseDeviceMonitor:self
               didDisconnectDeviceWithIdentifier:identifier];
    }
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

    NSInteger vendorID = [self numberProperty:kIOHIDVendorIDKey device:device].integerValue;
    NSInteger productID = [self numberProperty:kIOHIDProductIDKey device:device].integerValue;
    NSString *product = [self stringProperty:kIOHIDProductKey device:device];
    NSString *manufacturer = [self stringProperty:kIOHIDManufacturerKey device:device];
    NSString *serial = [self stringProperty:kIOHIDSerialNumberKey device:device];
    id uniqueID = [self objectProperty:kIOHIDUniqueIDKey device:device];
    NSNumber *locationID = [self numberProperty:kIOHIDLocationIDKey device:device];

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
