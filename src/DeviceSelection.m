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

NSString *STSelectMostRecentlyUsedProfileIdentifier(
    NSSet<NSString *> *connectedMouseIdentifiers,
    NSDictionary<NSString *, NSNumber *> *usageOrder) {
    NSString *selected = STTrackpadProfileIdentifier;
    unsigned long long selectedOrder =
        usageOrder[STTrackpadProfileIdentifier].unsignedLongLongValue;

    for (NSString *identifier in connectedMouseIdentifiers) {
        unsigned long long order = usageOrder[identifier].unsignedLongLongValue;
        if (order > selectedOrder ||
            (order == selectedOrder && order > 0 &&
             [identifier compare:selected] == NSOrderedAscending)) {
            selected = identifier;
            selectedOrder = order;
        }
    }
    return selected;
}
