/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLPeerSessionInfo;

//
// Interface: TLJoinCallRoomIQSerializer
//

@interface TLJoinCallRoomIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLJoinCallRoomIQ
//

@interface TLJoinCallRoomIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *callRoomId;
@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSArray<TLPeerSessionInfo *> *p2pSessionIds;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeId:(nonnull NSUUID *)twincodeId p2pSessionIds:(nonnull NSArray<TLPeerSessionInfo *> *)p2pSessionIds;

@end
