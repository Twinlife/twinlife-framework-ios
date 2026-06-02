/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterIQ.h"

//
// Interface: TLListRosterIQSerializer
//

@interface TLListRosterIQSerializer : TLSecureRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLListRosterIQ
//

@interface TLListRosterIQ : TLSecureRosterIQ

@property (readonly) int64_t minimumCreationTime;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId minimumCreationTime:(int64_t)minimumCreationTime;

@end
