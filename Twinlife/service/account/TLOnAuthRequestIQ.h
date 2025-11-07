/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnAuthRequestIQSerializer
//

@interface TLOnAuthRequestIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnAuthRequestIQ
//

@interface TLOnAuthRequestIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSData *serverSignature;
@property (readonly) int serverLatency;
@property (readonly) int64_t serverTimestamp;
@property (readonly) int64_t deviceTimestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq serverSignature:(nonnull NSData *)serverSignature serverLatency:(int)serverLatency serverTimestamp:(int64_t)serverTimestamp deviceTimestamp:(int64_t)deviceTimestamp;

@end
