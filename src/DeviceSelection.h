#import <Foundation/Foundation.h>

#import "DeviceProfile.h"

NS_ASSUME_NONNULL_BEGIN

// Selects the newest connected device, using its identifier as a stable tie-breaker.
NSString *STSelectActiveProfileIdentifier(
    NSDictionary<NSString *, NSDate *> *connectedAt);

// Selects the most recently used connected profile. The built-in trackpad is
// always eligible and is the fallback when no connected device has been used.
NSString *STSelectMostRecentlyUsedProfileIdentifier(
    NSSet<NSString *> *connectedMouseIdentifiers,
    NSDictionary<NSString *, NSNumber *> *usageOrder);

NS_ASSUME_NONNULL_END
