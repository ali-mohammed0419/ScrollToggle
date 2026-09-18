#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

@class MouseDeviceMonitor;

@interface MouseDeviceDescriptor : NSObject

@property (copy, readonly) NSString *identifier;
@property (copy, readonly) NSString *displayName;
@property (copy, readonly) NSString *transport;
@property (readonly) NSInteger vendorID;
@property (readonly) NSInteger productID;

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                         transport:(NSString *)transport
                          vendorID:(NSInteger)vendorID
                         productID:(NSInteger)productID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@protocol MouseDeviceMonitorDelegate <NSObject>
- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
        didConnectDevice:(MouseDeviceDescriptor *)device;
- (void)mouseDeviceMonitor:(MouseDeviceMonitor *)monitor
      didDisconnectDeviceWithIdentifier:(NSString *)identifier;
@end

@interface MouseDeviceMonitor : NSObject {
@private
    IOHIDManagerRef _manager;
}

@property (weak, nullable) id<MouseDeviceMonitorDelegate> delegate;

// Returns the external mice already connected when monitoring starts.
- (nullable NSArray<MouseDeviceDescriptor *> *)startMonitoringWithError:(NSError **)error;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END
