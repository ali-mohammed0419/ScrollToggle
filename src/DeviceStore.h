#import <Foundation/Foundation.h>

#import "DeviceProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceStore : NSObject

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSArray<DeviceProfile *> *)allProfiles;
- (nullable DeviceProfile *)profileForIdentifier:(NSString *)identifier;
- (DeviceProfile *)ensureTrackpadProfileWithNaturalScrolling:(BOOL)naturalScrolling;
- (DeviceProfile *)upsertMouseWithIdentifier:(NSString *)identifier
                                  displayName:(NSString *)displayName
                                    transport:(NSString *)transport
                                     vendorID:(NSInteger)vendorID
                                    productID:(NSInteger)productID
                                         seen:(NSDate *)seen;
- (void)setNaturalScrolling:(BOOL)naturalScrolling
              forIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
