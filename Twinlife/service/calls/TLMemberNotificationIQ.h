/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

#import "TLPeerCallService.h"

//
// Interface: TLMemberNotificationIQSerializer
//

@interface TLMemberNotificationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLMemberNotificationIQ
//

@interface TLMemberNotificationIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *callRoomId;
@property (readonly, nonnull) NSString *memberId;
@property (readonly, nullable) NSUUID *p2pSessionId;
@property (readonly) TLMemberStatus status;
@property (readonly) int maxFrameWidth;
@property (readonly) int maxFrameHeight;
@property (readonly) int maxFrameRate;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status maxFrameWidth:(int)maxFrameWidth maxFrameHeight:(int)maxFrameHeight maxFrameRate:(int)maxFrameRate;

@end
