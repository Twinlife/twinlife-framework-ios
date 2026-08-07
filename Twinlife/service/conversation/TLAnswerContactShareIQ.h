/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLConversationService.h"

@class TLDescriptorId;

//
// Interface: TLAnswerContactShareIQSerializer
//

@interface TLAnswerContactShareIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAnswerContactShareIQ
//

@interface TLAnswerContactShareIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *contactShareDescriptorId;

@property (readonly) TLInvitationDescriptorStatusType status;

@property (readonly) BOOL autoAnswer;

@property (readonly, nullable) NSUUID *invitationTwincodeOutboundId;

@property (readonly, nullable) NSString *invitationTwincodeOutboundPubkey;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId contactShareDescriptorId:(nonnull TLDescriptorId *)contactShareDescriptorId status:(TLInvitationDescriptorStatusType)status autoAnswer:(BOOL)autoAnswer invitationTwincodeOutboundId:(nullable NSUUID *) invitationTwincodeOutboundId invitationTwincodeOutboundPubkey:(nullable NSString *)invitationTwincodeOutboundPubkey;

@end
