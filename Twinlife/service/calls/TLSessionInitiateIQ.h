/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

// Set of flags representing the offer and offerToReceive
#define OFFER_DATA           0x01
#define OFFER_AUDIO          0x02
#define OFFER_VIDEO          0x04
#define OFFER_VIDEO_BELL     0x08
#define OFFER_GROUP_CALL     0x10
#define OFFER_ANSWER         0x20    // The SDP is an answer
#define OFFER_COMPRESSED     0x40    // Indicates the SDP is compressed.
#define OFFER_TRANSFER       0x80    // The SDP is a session transfer (added in 1.3.0)
#define OFFER_ENCRYPT_MASK   0x0ff00 // The encryption key index.
#define OFFER_ENCRYPT_SHIFT  8
#define OFFER_VOIP           (OFFER_AUDIO | OFFER_VIDEO)

@class TLSdp;

//
// Interface: TLSessionInitiateIQSerializer
//

@interface TLSessionInitiateIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSessionInitiateIQ
//

@interface TLSessionInitiateIQ : TLBinaryPacketIQ

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
