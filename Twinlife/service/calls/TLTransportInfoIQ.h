/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLSdp;

//
// Interface: TLTransportInfoIQSerializer
//

@interface TLTransportInfoIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLTransportInfoIQ
//

@interface TLTransportInfoIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *to;
@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly) int64_t expirationDeadline;
@property (readonly) int mode;
@property (readonly, nonnull) NSData *sdp;
@property (readonly, nullable) TLTransportInfoIQ *next;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId expirationDeadline:(int64_t)expirationDeadline mode:(int)mode sdp:(nonnull NSData*)sdp next:(nullable TLTransportInfoIQ *)next;

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp;

@end
