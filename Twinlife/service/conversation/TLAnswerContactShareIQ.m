/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAnswerContactShareIQ.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * AnswerContactShare IQ.
 * <p>
 * Schema version 1
 * Date: 2026/07/06
 *
 * <pre>
 * {
 *  "schemaId":"f2a9dbf3-4439-47a6-b2ab-20ac59b57d48",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AnswerContactShareIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"},
 *     {"name":"sequenceId", "type":"long"},
 *     {"name":"accept", "type":"boolean"},
 *     {"name":"invitationTwincodeOutboundId", "type":["null", "UUID"]},
 *     {"name":"invitationTwincodeOutboundPubkey", "type":["null", "string"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLAnswerContactShareIQSerializer
//

@implementation TLAnswerContactShareIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAnswerContactShareIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAnswerContactShareIQ *answerContactShareIq = (TLAnswerContactShareIQ *)object;
    
    [encoder writeUUID:answerContactShareIq.contactShareDescriptorId.twincodeOutboundId];
    [encoder writeLong:answerContactShareIq.contactShareDescriptorId.sequenceId];
    
    [encoder writeEnum:[TLInvitationDescriptor fromInvitationStatus:answerContactShareIq.status]];
    [encoder writeBoolean:answerContactShareIq.autoAnswer];
    [encoder writeOptionalUUID:answerContactShareIq.invitationTwincodeOutboundId];
    [encoder writeOptionalString:answerContactShareIq.invitationTwincodeOutboundPubkey];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    
    TLInvitationDescriptorStatusType status = [TLInvitationDescriptor toInvitationStatus:[decoder readEnum]];
    BOOL autoAnswer = [decoder readBoolean];
    NSUUID *invitationTwincodeOutboundId = [decoder readOptionalUUID];
    
    NSString *invitationTwincodeOutboundPubkey = [decoder readOptionalString];
      
    return [[TLAnswerContactShareIQ alloc] initWithSerializer:self requestId:requestId contactShareDescriptorId:descriptorId status:status autoAnswer:autoAnswer invitationTwincodeOutboundId:invitationTwincodeOutboundId invitationTwincodeOutboundPubkey:invitationTwincodeOutboundPubkey];
}

@end

//
// Implementation: TLAnswerContactShareIQ
//

@implementation TLAnswerContactShareIQ

static TLAnswerContactShareIQSerializer *IQ_ANSWER_CONTACT_SHARE_SERIALIZER_1;
static const int IQ_ANSWER_CONTACT_SHARE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ANSWER_CONTACT_SHARE_SERIALIZER_1 = [[TLAnswerContactShareIQSerializer alloc] initWithSchema:@"f2a9dbf3-4439-47a6-b2ab-20ac59b57d48" schemaVersion:IQ_ANSWER_CONTACT_SHARE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ANSWER_CONTACT_SHARE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ANSWER_CONTACT_SHARE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ANSWER_CONTACT_SHARE_SERIALIZER_1;
}


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId contactShareDescriptorId:(nonnull TLDescriptorId *)contactShareDescriptorId status:(TLInvitationDescriptorStatusType)status autoAnswer:(BOOL)autoAnswer invitationTwincodeOutboundId:(nullable NSUUID *) invitationTwincodeOutboundId invitationTwincodeOutboundPubkey:(nullable NSString *)invitationTwincodeOutboundPubkey {

    self = [super initWithSerializer:serializer requestId:requestId];

    if (self) {
        _contactShareDescriptorId = contactShareDescriptorId;
        _status = status;
        _autoAnswer = autoAnswer;
        _invitationTwincodeOutboundId = invitationTwincodeOutboundId;
        _invitationTwincodeOutboundPubkey = invitationTwincodeOutboundPubkey;
    }
    
    return self;
}

@end
