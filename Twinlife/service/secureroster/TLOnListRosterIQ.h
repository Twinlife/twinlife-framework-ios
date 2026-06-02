/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLSignedRosterGroup;

//
// Interface: TLOnListRosterIQSerializer
//

@interface TLOnListRosterIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnListRosterIQ
//

@interface TLOnListRosterIQ : TLBinaryPacketIQ

@property (readonly) int maxMemberCount;
@property (readonly, nonnull) NSArray<TLSignedRosterGroup *> *keys;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId maxMemberCount:(int)maxMemberCount keys:(nonnull NSArray<TLSignedRosterGroup *> *)keys;

@end
