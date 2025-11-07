/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnPushIQSerializer
//

@interface TLOnPushIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnPushIQ
//

@interface TLOnPushIQ : TLBinaryPacketIQ

@property (readonly) int deviceState;
@property (readonly) int64_t receivedTimestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState receivedTimestamp:(int64_t)receivedTimestamp;

@end
