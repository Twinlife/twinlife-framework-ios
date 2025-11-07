/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLUpdateGeolocationIQSerializer
//

@interface TLUpdateGeolocationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateGeolocationIQ
//

@interface TLUpdateGeolocationIQ : TLBinaryPacketIQ

@property (readonly) int64_t updatedTimestamp;
@property (readonly) double longitude;
@property (readonly) double latitude;
@property (readonly) double altitude;
@property (readonly) double mapLongitudeDelta;
@property (readonly) double mapLatitudeDelta;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId updatedTimestamp:(int64_t)updatedTimestamp longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta;

@end

//
// Interface: TLOnUpdateGeolocationIQ
//

@interface TLOnUpdateGeolocationIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

@end
