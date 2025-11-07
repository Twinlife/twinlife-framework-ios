/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLGetObjectIQSerializer
//

@interface TLGetObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLGetObjectIQ
//

@interface TLGetObjectIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *objectSchemaId;
@property (readonly, nonnull) NSUUID *objectId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectSchemaId:(nonnull NSUUID *)objectSchemaId objectId:(nonnull NSUUID *)objectId;

@end
