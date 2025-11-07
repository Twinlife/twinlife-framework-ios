/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLListObjectIQSerializer
//

@interface TLListObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLListObjectIQ
//

@interface TLListObjectIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *objectSchemaId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectSchemaId:(nonnull NSUUID *)objectSchemaId;

@end
