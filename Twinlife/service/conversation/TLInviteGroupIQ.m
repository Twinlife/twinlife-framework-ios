/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInviteGroupIQ.h"
#import "TLSerializerFactory.h"
#import "TLInvitationDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * InviteGroup IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/08/28
 *
 * <pre>
 * {
 *  "schemaId":"55e698ff-b429-425f-bcaa-0b21d4620621",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"InviteGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"groupTwincodeOutboundId", "type":"uuid"},
 *     {"name":"publicKey", "type":[null, "String"]},
 *     {"name":"name", "type":"String"},
 *     {"name":"createdTimestamp", "type":"long"},
 *     {"name":"sentTimestamp", "type":"long"},
 *     {"name":"expireTimeout", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLInviteGroupIQSerializer
//

@implementation TLInviteGroupIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLInviteGroupIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLInviteGroupIQ *inviteGroupIQ = (TLInviteGroupIQ *)object;
    TLInvitationDescriptor *invitationDescriptor = inviteGroupIQ.invitationDescriptor;

    [encoder writeUUID:invitationDescriptor.descriptorId.twincodeOutboundId];
    [encoder writeLong:invitationDescriptor.descriptorId.sequenceId];
    [encoder writeUUID:invitationDescriptor.groupTwincodeId];
    [encoder writeOptionalString:invitationDescriptor.publicKey];
    [encoder writeString:invitationDescriptor.name];
    [encoder writeLong:invitationDescriptor.createdTimestamp];
    [encoder writeLong:invitationDescriptor.sentTimestamp];
    [encoder writeLong:invitationDescriptor.expireTimeout];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    NSUUID *groupTwincodeId = [decoder readUUID];
    NSString *publicKey = [decoder readOptionalString];
    NSString *name = [decoder readString];
    int64_t createdTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int64_t expireTimeout = [decoder readLong];

    TLInvitationDescriptor *invitationDescriptor = [[TLInvitationDescriptor alloc] initWithDescriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId] groupTwincodeId:groupTwincodeId inviterTwincodeId:twincodeOutboundId name:name publicKey:publicKey creationDate:createdTimestamp sendDate:sentTimestamp expireTimeout:expireTimeout];
    return [[TLInviteGroupIQ alloc] initWithSerializer:self requestId:requestId invitationDescriptor:invitationDescriptor];
}

@end

//
// Implementation: TLInviteGroupIQ
//

@implementation TLInviteGroupIQ

static TLInviteGroupIQSerializer *IQ_INVITE_GROUP_SERIALIZER_2;
static const int IQ_INVITE_GROUP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_INVITE_GROUP_SERIALIZER_2 = [[TLInviteGroupIQSerializer alloc] initWithSchema:@"55e698ff-b429-425f-bcaa-0b21d4620621" schemaVersion:IQ_INVITE_GROUP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_INVITE_GROUP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_INVITE_GROUP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_INVITE_GROUP_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

@end
