/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLSettingsIQSerializer
//

@interface TLSettingsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSettingsIQ
//

@interface TLSettingsIQ : TLBinaryPacketIQ

@property (readonly) BOOL hasPeerSettings;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSString *> *settings;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId hasPeerSettings:(BOOL)hasPeerSettings settings:(nonnull NSDictionary<NSUUID *, NSString *> *)settings;
@end
