#import <Foundation/Foundation.h>

#import "DeviceSelection.h"

static void STAssert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAILED: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        STAssert([STSelectMostRecentlyUsedProfileIdentifier(
                     [NSSet set], @{})
                     isEqualToString:STTrackpadProfileIdentifier],
                 @"Trackpad should be the empty-history fallback");

        NSSet *connected = [NSSet setWithArray:@[@"mouse.a", @"mouse.b"]];
        NSDictionary *order = @{
            STTrackpadProfileIdentifier: @1,
            @"mouse.a": @2,
            @"mouse.b": @3,
            @"mouse.disconnected": @99
        };
        STAssert([STSelectMostRecentlyUsedProfileIdentifier(connected, order)
                     isEqualToString:@"mouse.b"],
                 @"Newest connected mouse should win");

        order = @{
            STTrackpadProfileIdentifier: @4,
            @"mouse.a": @2,
            @"mouse.b": @3
        };
        STAssert([STSelectMostRecentlyUsedProfileIdentifier(connected, order)
                     isEqualToString:STTrackpadProfileIdentifier],
                 @"A more recently used trackpad should win");

        puts("DeviceSelectionTests passed");
    }
    return 0;
}
