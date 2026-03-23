/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLMemberSessionInfo;

//
// Interface: TLOnJoinMeetingIQSerializer
//

@interface TLOnJoinMeetingIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnJoinMeetingIQ
//

@interface TLOnJoinMeetingIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *callRoomId;
@property (readonly, nonnull) NSString *memberId;
@property (readonly, nullable) NSArray<TLMemberSessionInfo *> *members;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nullable NSArray<TLMemberSessionInfo *> *)members;

@end
