/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLSecureRosterIQSerializer
//

@interface TLSecureRosterIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion class:(nonnull Class) clazz;

@end

//
// Interface: TLSecureRosterIQ
//

@interface TLSecureRosterIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *rosterId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId;

@end
