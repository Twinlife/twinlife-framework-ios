/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLQueryInfo;

//
// Interface: TLOnQueryStatsIQSerializer
//

@interface TLOnQueryStatsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnQueryStatsIQ
//

@interface TLOnQueryStatsIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLQueryInfo *queryInfo;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq queryInfo:(nonnull TLQueryInfo *)queryInfo;

@end
