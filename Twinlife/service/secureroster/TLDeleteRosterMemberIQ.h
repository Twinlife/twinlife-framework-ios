/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterIQ.h"

//
// Interface: TLDeleteRosterMemberIQSerializer
//

@interface TLDeleteRosterMemberIQSerializer : TLSecureRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLDeleteRosterMemberIQ
//

@interface TLDeleteRosterMemberIQ : TLSecureRosterIQ

@property (readonly, nonnull) NSUUID *memberId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId memberId:(nonnull NSUUID *)memberId;

@end
