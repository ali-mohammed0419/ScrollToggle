#import <Foundation/Foundation.h>

#import "DeviceProfile.h"

NS_ASSUME_NONNULL_BEGIN

// Selects the newest connected device, using its identifier as a stable tie-breaker.
NSString *STSelectActiveProfileIdentifier(
    NSDictionary<NSString *, NSDate *> *connectedAt);

NS_ASSUME_NONNULL_END
