/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnCreateObjectIQSerializer
//

@interface TLOnCreateObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnCreateObjectIQ
//

@interface TLOnCreateObjectIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *objectId;
@property (readonly) int64_t creationDate;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectId:(nonnull NSUUID *)objectId creationDate:(int64_t)creationDate;

@end
