/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLMemberSessionInfo;

//
// Interface: TLOnJoinCallRoomIQSerializer
//

@interface TLOnJoinCallRoomIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnJoinCallRoomIQ
//

@interface TLOnJoinCallRoomIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *memberId;
@property (readonly, nullable) NSArray<TLMemberSessionInfo *> *members;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId members:(nullable NSArray<TLMemberSessionInfo *> *)members;

@end
