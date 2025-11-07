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
// Interface: TLCreateCallRoomIQSerializer
//

@interface TLCreateCallRoomIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateCallRoomIQ
//

@interface TLCreateCallRoomIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *ownerId;
@property (readonly, nonnull) NSUUID *memberId;
@property (readonly) int mode;
@property (readonly, nullable) NSArray<TLMemberSessionInfo *> *members;
@property (readonly, nullable) NSString *sfuURI;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ownerId:(nonnull NSUUID *)ownerId memberId:(nonnull NSUUID *)memberId mode:(int)mode members:(nullable NSArray<TLMemberSessionInfo *> *)members sfuURI:(nullable NSString *)sfuURI;

@end
