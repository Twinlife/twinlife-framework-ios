/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLGeolocationDescriptor;

//
// Interface: TLPushGeolocationIQSerializer
//

@interface TLPushGeolocationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushGeolocationIQ
//

@interface TLPushGeolocationIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLGeolocationDescriptor *geolocationDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId geolocationDescriptor:(nonnull TLGeolocationDescriptor *)geolocationDescriptor;

@end
