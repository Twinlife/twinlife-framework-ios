/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPushContactShareIQ.h"
#import "TLContactShareDescriptorImpl.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushPoll IQ.
 * <p>
 * Schema version 1
 * Date: 2026/07/04
 *
 * <pre>
 * {
 *  "schemaId":"9c338e8d-f7ec-40a9-b5e5-77e31ede8939",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushContactShareIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"name", "type":"string"},
 *     {"name":"status", "type":"enum"},
 *     {"name":"avatar", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushContactShareIQSerializer
//

@implementation TLPushContactShareIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushContactShareIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushContactShareIQ *pushContactShareIQ = (TLPushContactShareIQ *)object;
    
    TLContactShareDescriptor *contactShareDescriptor = pushContactShareIQ.contactShareDescriptor;
    
    [encoder writeUUID:contactShareDescriptor.descriptorId.twincodeOutboundId];
    [encoder writeLong:contactShareDescriptor.descriptorId.sequenceId];
    [encoder writeOptionalUUID:contactShareDescriptor.sendTo];
    
    TLDescriptorId *replyTo = contactShareDescriptor.replyTo;
    
    if (!replyTo) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    
    [encoder writeLong:contactShareDescriptor.createdTimestamp];
    [encoder writeLong:contactShareDescriptor.sentTimestamp];
    [encoder writeLong:contactShareDescriptor.expireTimeout];
    
    [encoder writeString:contactShareDescriptor.name];
    [encoder writeEnum:[TLInvitationDescriptor fromInvitationStatus:contactShareDescriptor.status]];
    [encoder writeData:pushContactShareIQ.avatar];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];
    
    int64_t createdTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int64_t expireTimeout = [decoder readLong];

    NSString *name = [decoder readString];
    TLInvitationDescriptorStatusType status = [TLInvitationDescriptor toInvitationStatus:[decoder readEnum]];
    NSData *avatar = [decoder readData];
    
    TLContactShareDescriptor *contactShareDescriptor = [[TLContactShareDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId expireTimeout:expireTimeout sendTo:sendTo replyTo:replyTo createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp name:name status:status];
    
    return [[TLPushContactShareIQ alloc] initWithSerializer:self requestId:requestId contactShareDescriptor:contactShareDescriptor avatar:avatar];
}

@end

//
// Implementation: TLPushContactShareIQ
//

@implementation TLPushContactShareIQ

static TLPushContactShareIQSerializer *IQ_PUSH_CONTACT_SHARE_SERIALIZER_1;
static const int IQ_PUSH_CONTACT_SHARE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_PUSH_CONTACT_SHARE_SERIALIZER_1 = [[TLPushContactShareIQSerializer alloc] initWithSchema:@"9c338e8d-f7ec-40a9-b5e5-77e31ede8939" schemaVersion:IQ_PUSH_CONTACT_SHARE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_CONTACT_SHARE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_PUSH_CONTACT_SHARE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_PUSH_CONTACT_SHARE_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId contactShareDescriptor:(nonnull TLContactShareDescriptor *)contactShareDescriptor avatar:(nonnull NSData *)avatar {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _contactShareDescriptor = contactShareDescriptor;
        _avatar = avatar;
    }
    
    return self;
}

@end
