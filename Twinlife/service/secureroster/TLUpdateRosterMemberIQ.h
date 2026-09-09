/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterIQ.h"

@class TLMemberInfo;

//
// Interface: TLUpdateRosterMemberIQSerializer
//

@interface TLUpdateRosterMemberIQSerializer : TLSecureRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateRosterMemberIQ
//

@interface TLUpdateRosterMemberIQ : TLSecureRosterIQ

@property (readonly, nonnull) NSUUID *signingKeyId;
@property (readonly, nonnull) NSArray<TLMemberInfo *> *members;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId signingKeyId:(nonnull NSUUID *)signingKeyId members:(nonnull NSArray<TLMemberInfo *> *)members;

@end
