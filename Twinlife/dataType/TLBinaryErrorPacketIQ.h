/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLBinaryErrorPacketIQSerializer
//

@interface TLBinaryErrorPacketIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLBinaryErrorPacketIQ
//

/// Base class of binary packets.
@interface TLBinaryErrorPacketIQ : TLBinaryPacketIQ

@property (readonly) TLBaseServiceErrorCode errorCode;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode;

@end
