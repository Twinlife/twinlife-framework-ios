/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLSdp;

//
// Interface: TLSessionUpdateIQSerializer
//

@interface TLSessionUpdateIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSessionUpdateIQ
//

@interface TLSessionUpdateIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *to;
@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly) int64_t expirationDeadline;
@property (readonly) int updateType;
@property (readonly, nonnull) NSData *sdp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId expirationDeadline:(int64_t)expirationDeadline updateType:(int)updateType sdp:(nonnull NSData*)sdp;

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp;

@end
