#import "DeviceProfile.h"

NSString * const STTrackpadProfileIdentifier = @"fallback.trackpad";

@implementation DeviceProfile

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                         transport:(NSString *)transport
                          vendorID:(NSInteger)vendorID
                         productID:(NSInteger)productID
                   naturalScrolling:(BOOL)naturalScrolling
                       firstSeenAt:(NSDate *)firstSeenAt
                        lastSeenAt:(NSDate *)lastSeenAt {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _displayName = [displayName copy];
        _transport = [transport copy];
        _vendorID = vendorID;
        _productID = productID;
        _naturalScrolling = naturalScrolling;
        _firstSeenAt = firstSeenAt;
        _lastSeenAt = lastSeenAt;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    NSString *identifier = dictionary[@"identifier"];
    NSString *displayName = dictionary[@"displayName"];
    NSString *transport = dictionary[@"transport"];
    NSNumber *vendorID = dictionary[@"vendorID"];
    NSNumber *productID = dictionary[@"productID"];
    NSNumber *naturalScrolling = dictionary[@"naturalScrolling"];
    NSDate *firstSeenAt = dictionary[@"firstSeenAt"];
    NSDate *lastSeenAt = dictionary[@"lastSeenAt"];

    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0 ||
        ![displayName isKindOfClass:[NSString class]] || displayName.length == 0 ||
        ![transport isKindOfClass:[NSString class]] ||
        ![vendorID isKindOfClass:[NSNumber class]] ||
        ![productID isKindOfClass:[NSNumber class]] ||
        ![naturalScrolling isKindOfClass:[NSNumber class]] ||
        ![firstSeenAt isKindOfClass:[NSDate class]] ||
        ![lastSeenAt isKindOfClass:[NSDate class]]) {
        return nil;
    }

    return [self initWithIdentifier:identifier
                        displayName:displayName
                          transport:transport
                           vendorID:vendorID.integerValue
                          productID:productID.integerValue
                    naturalScrolling:naturalScrolling.boolValue
                        firstSeenAt:firstSeenAt
                         lastSeenAt:lastSeenAt];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"identifier": self.identifier,
        @"displayName": self.displayName,
        @"transport": self.transport,
        @"vendorID": @(self.vendorID),
        @"productID": @(self.productID),
        @"naturalScrolling": @(self.naturalScrolling),
        @"firstSeenAt": self.firstSeenAt,
        @"lastSeenAt": self.lastSeenAt
    };
}

@end
