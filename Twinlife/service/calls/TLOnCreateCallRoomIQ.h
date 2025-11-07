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
// Interface: TLOnCreateCallRoomIQSerializer
//

@interface TLOnCreateCallRoomIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnCreateCallRoomIQ
//

@interface TLOnCreateCallRoomIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *callRoomId;
@property (readonly, nonnull) NSString *memberId;
@property (readonly) int mode;
@property (readonly) int maxMemberCount;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount;

@end
