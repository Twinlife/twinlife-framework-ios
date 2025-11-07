/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLSetPushTokenIQSerializer
//

@interface TLSetPushTokenIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSetPushTokenIQ
//

@interface TLSetPushTokenIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *environmentId;
@property (readonly, nonnull) NSString *pushVariant;
@property (readonly, nonnull) NSString *pushToken;
@property (readonly, nullable) NSString *pushRemoteToken;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId environmentId:(nonnull NSUUID *)environmentId pushVariant:(nonnull NSString *)pushVariant pushToken:(nonnull NSString *)pushToken pushRemoteToken:(nullable NSString *)pushRemoteToken;

@end
