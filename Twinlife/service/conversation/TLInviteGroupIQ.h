/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLInvitationDescriptor;

//
// Interface: TLInviteGroupIQSerializer
//

@interface TLInviteGroupIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLInviteGroupIQ
//

@interface TLInviteGroupIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLInvitationDescriptor *invitationDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

@end
