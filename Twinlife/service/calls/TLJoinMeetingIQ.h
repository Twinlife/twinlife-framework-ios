/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLPeerSessionInfo;

//
// Interface: TLJoinMeetingIQSerializer
//

@interface TLJoinMeetingIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLJoinMeetingIQ
//

@interface TLJoinMeetingIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *meetingTwincodeId;
@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly) int maxWaitTime;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId meetingTwincodeId:(nonnull NSUUID *)meetingTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId maxWaitTime:(int)maxWaitTime;

@end
