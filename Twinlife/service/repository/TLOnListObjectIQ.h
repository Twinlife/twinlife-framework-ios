/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnListObjectIQSerializer
//

@interface TLOnListObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnListObjectIQ
//

@interface TLOnListObjectIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSArray<NSUUID *> *objectIds;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectIds:(nonnull NSArray<NSUUID *> *)objectIds;

@end
