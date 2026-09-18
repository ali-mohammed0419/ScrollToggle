#import "DeviceSelection.h"

NSString *STSelectActiveProfileIdentifier(
    NSDictionary<NSString *, NSDate *> *connectedAt) {
    if (connectedAt.count == 0) {
        return STTrackpadProfileIdentifier;
    }

    NSArray<NSString *> *identifiers =
        [connectedAt.allKeys sortedArrayUsingComparator:
            ^NSComparisonResult(NSString *left, NSString *right) {
                NSDate *leftDate = connectedAt[left] ?: [NSDate distantPast];
                NSDate *rightDate = connectedAt[right] ?: [NSDate distantPast];
                NSComparisonResult dateResult = [rightDate compare:leftDate];
                if (dateResult != NSOrderedSame) {
                    return dateResult;
                }
                return [left compare:right];
            }];
    return identifiers.firstObject;
}
