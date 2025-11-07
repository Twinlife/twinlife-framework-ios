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
// Interface: TLSessionAcceptIQSerializer
//

@interface TLSessionAcceptIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSessionAcceptIQ
//

@interface TLSessionAcceptIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *from;
@property (readonly, nonnull) NSString *to;
@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly) int offer;
@property (readonly) int offerToReceive;
@property (readonly) int priority;
@property (readonly) int64_t expirationDeadline;
@property (readonly) int majorVersion;
@property (readonly) int minorVersion;
@property (readonly) int frameSize;
@property (readonly) int frameRate;
@property (readonly) int estimatedDataSize;
@property (readonly) int operationCount;
@property (readonly, nonnull) NSData *sdp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId from:(nonnull NSString *)from to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId majorVersion:(int)majorVersion minorVersion:(int)minorVersion offer:(int)offer offerToReceive:(int)offerToReceive priority:(int)priority expirationDeadline:(int64_t)expirationDeadline frameSize:(int)frameSize frameRate:(int)frameRate estimatedDataSize:(int)estimatedDataSize operationCount:(int)operationCount sdp:(nonnull NSData*)sdp;

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp;

@end
