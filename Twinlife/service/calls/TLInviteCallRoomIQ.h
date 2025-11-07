/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLInviteCallRoomIQSerializer
//

@interface TLInviteCallRoomIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLInviteCallRoomIQ
//

@interface TLInviteCallRoomIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *callRoomId;
@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly) int mode;
@property (readonly, nullable) NSUUID *p2pSessionId;
@property (readonly) int maxMemberCount;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeId:(nonnull NSUUID *)twincodeId p2pSessionId:(nonnull NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount;

@end
