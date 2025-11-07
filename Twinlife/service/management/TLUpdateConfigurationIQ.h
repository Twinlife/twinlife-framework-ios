/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLUpdateConfigurationIQSerializer
//

@interface TLUpdateConfigurationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateConfigurationIQ
//

@interface TLUpdateConfigurationIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *environmentId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId environmentId:(nullable NSUUID *)environmentId;

@end
