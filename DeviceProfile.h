#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const STTrackpadProfileIdentifier;

@interface DeviceProfile : NSObject

@property (copy) NSString *identifier;
@property (copy) NSString *displayName;
@property (copy) NSString *transport;
@property NSInteger vendorID;
@property NSInteger productID;
@property BOOL naturalScrolling;
@property (strong) NSDate *firstSeenAt;
@property (strong) NSDate *lastSeenAt;

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                         transport:(NSString *)transport
                           vendorID:(NSInteger)vendorID
                          productID:(NSInteger)productID
                    naturalScrolling:(BOOL)naturalScrolling
                       firstSeenAt:(NSDate *)firstSeenAt
                        lastSeenAt:(NSDate *)lastSeenAt NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
