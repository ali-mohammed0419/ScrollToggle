#import "DeviceStore.h"

static NSString * const STProfilesDefaultsKey = @"DeviceProfiles";
static NSString * const STProfilesSchemaVersionKey = @"DeviceProfilesSchemaVersion";
static NSInteger const STProfilesSchemaVersion = 1;

@interface DeviceStore ()
@property (strong) NSUserDefaults *userDefaults;
@property (strong) NSMutableDictionary<NSString *, DeviceProfile *> *profiles;
@end

@implementation DeviceStore

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];
    if (self) {
        _userDefaults = userDefaults;
        _profiles = [NSMutableDictionary dictionary];
        [self loadProfiles];
    }
    return self;
}

- (void)loadProfiles {
    id storedProfiles = [self.userDefaults objectForKey:STProfilesDefaultsKey];
    if (![storedProfiles isKindOfClass:[NSArray class]]) {
        return;
    }

    for (id value in (NSArray *)storedProfiles) {
        if (![value isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        DeviceProfile *profile = [[DeviceProfile alloc] initWithDictionary:value];
        if (profile) {
            self.profiles[profile.identifier] = profile;
        }
    }
}

- (void)saveProfiles {
    NSArray<DeviceProfile *> *profiles = [self allProfiles];
    NSMutableArray *serialized = [NSMutableArray arrayWithCapacity:profiles.count];
    for (DeviceProfile *profile in profiles) {
        [serialized addObject:[profile dictionaryRepresentation]];
    }
    [self.userDefaults setInteger:STProfilesSchemaVersion
                           forKey:STProfilesSchemaVersionKey];
    [self.userDefaults setObject:serialized forKey:STProfilesDefaultsKey];
}

- (NSArray<DeviceProfile *> *)allProfiles {
    return [self.profiles.allValues sortedArrayUsingComparator:
        ^NSComparisonResult(DeviceProfile *left, DeviceProfile *right) {
            return [left.identifier compare:right.identifier];
        }];
}

- (DeviceProfile *)profileForIdentifier:(NSString *)identifier {
    return self.profiles[identifier];
}

- (DeviceProfile *)ensureTrackpadProfileWithNaturalScrolling:(BOOL)naturalScrolling {
    DeviceProfile *profile = self.profiles[STTrackpadProfileIdentifier];
    if (profile) {
        if (![profile.displayName isEqualToString:@"Trackpad"]) {
            profile.displayName = @"Trackpad";
            [self saveProfiles];
        }
        return profile;
    }

    NSDate *now = [NSDate date];
    profile = [[DeviceProfile alloc]
        initWithIdentifier:STTrackpadProfileIdentifier
               displayName:@"Trackpad"
                 transport:@"Built-in"
                  vendorID:0
                 productID:0
           naturalScrolling:naturalScrolling
               firstSeenAt:now
                lastSeenAt:now];
    self.profiles[profile.identifier] = profile;
    [self saveProfiles];
    return profile;
}

- (DeviceProfile *)upsertMouseWithIdentifier:(NSString *)identifier
                                  displayName:(NSString *)displayName
                                    transport:(NSString *)transport
                                     vendorID:(NSInteger)vendorID
                                    productID:(NSInteger)productID
                                         seen:(NSDate *)seen {
    DeviceProfile *profile = self.profiles[identifier];
    if (!profile) {
        profile = [[DeviceProfile alloc]
            initWithIdentifier:identifier
                   displayName:displayName
                     transport:transport
                      vendorID:vendorID
                     productID:productID
               naturalScrolling:NO
                   firstSeenAt:seen
                    lastSeenAt:seen];
        self.profiles[identifier] = profile;
    } else {
        profile.displayName = displayName;
        profile.transport = transport;
        profile.vendorID = vendorID;
        profile.productID = productID;
        profile.lastSeenAt = seen;
    }
    [self saveProfiles];
    return profile;
}

- (void)setNaturalScrolling:(BOOL)naturalScrolling
              forIdentifier:(NSString *)identifier {
    DeviceProfile *profile = self.profiles[identifier];
    if (!profile) {
        return;
    }
    profile.naturalScrolling = naturalScrolling;
    [self saveProfiles];
}

@end
