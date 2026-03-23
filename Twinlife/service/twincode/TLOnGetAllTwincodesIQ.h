/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLTwincodeInfo;

//
// Interface: TLOnGetAllTwincodesIQSerializer
//

@interface TLOnGetAllTwincodesIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetAllTwincodesIQ
//

@interface TLOnGetAllTwincodesIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *twincodeIdsBySchema;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeIdsBySchema:(nonnull NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *)twincodeIdsBySchema;

@end
