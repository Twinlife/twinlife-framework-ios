/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLCreateAccountIQSerializer
//

@interface TLCreateAccountIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateAccountIQ
//

@interface TLCreateAccountIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *applicationId;
@property (readonly, nonnull) NSUUID *serviceId;
@property (readonly, nonnull) NSString *apiKey;
@property (readonly, nonnull) NSString *accessToken;
@property (readonly, nonnull) NSString *applicationName;
@property (readonly, nonnull) NSString *applicationVersion;
@property (readonly, nonnull) NSString *twinlifeVersion;
@property (readonly, nonnull) NSString *accountIdentifier;
@property (readonly, nonnull) NSString *accountPassword;
@property (readonly, nullable) NSString *authToken;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId apiKey:(nonnull NSString *)apiKey accessToken:(nonnull NSString *)accessToken applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion twinlifeVersion:(nonnull NSString *)twinlifeVersion accountIdentifier:(nonnull NSString *)accountIdentifier accountPassword:(nonnull NSString *)accountPassword  authToken:(nullable NSString *)authToken;

@end
