/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLJoinGroupIQ.h"
#import "TLSerializerFactory.h"
#import "TLInvitationDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * JoinGroupIQ IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/08/28
 *
 * <pre>
 * {
 *  "schemaId":"c1315d7f-bf10-4cec-811b-84c44302e7bd",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"JoinGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"},
 *     {"name":"sequenceId", "type":"long"}}
 *     {"name":"groupTwincodeId", "type":"uuid"},
 *     {"name":"mode", "type":"int"
 *      0 => {},
 *      1 => {{"name":"memberTwincodeId", "type":"uuid"},
 *          {"name":"publicKey", "type":[null, "String"]},
 *          {"name":"secret", "type":[null, "bytes"]}}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLJoinGroupIQSerializer
//

@implementation TLJoinGroupIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLJoinGroupIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLJoinGroupIQ *joinGroupIQ = (TLJoinGroupIQ *)object;
    TLDescriptorId *descriptorId = joinGroupIQ.invitationDescriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeUUID:joinGroupIQ.groupTwincodeId];
    if (joinGroupIQ.memberTwincodeId == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:joinGroupIQ.memberTwincodeId];
        [encoder writeOptionalString:joinGroupIQ.publicKey];
        [encoder writeOptionalData:joinGroupIQ.secretKey];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    NSUUID *groupTwincodeId = [decoder readUUID];
    int mode = [decoder readEnum];
    NSUUID *memberTwincodeId = nil;
    NSString *publicKey = nil;
    NSData *secretKey = nil;
    if (mode != 0) {
        memberTwincodeId = [decoder readUUID];
        publicKey = [decoder readOptionalString];
        secretKey = [decoder readOptionalData];
    }

    TLDescriptorId *invitationDescriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    return [[TLJoinGroupIQ alloc] initWithSerializer:self requestId:requestId invitationDescriptorId:invitationDescriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId publicKey:publicKey secretKey:secretKey];
}

@end

//
// Implementation: TLJoinGroupIQ
//

@implementation TLJoinGroupIQ

static TLJoinGroupIQSerializer *IQ_JOIN_GROUP_SERIALIZER_2;
static const int IQ_JOIN_GROUP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_JOIN_GROUP_SERIALIZER_2 = [[TLJoinGroupIQSerializer alloc] initWithSchema:@"c1315d7f-bf10-4cec-811b-84c44302e7bd" schemaVersion:IQ_JOIN_GROUP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_JOIN_GROUP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_JOIN_GROUP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_JOIN_GROUP_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invitationDescriptorId:(nonnull TLDescriptorId *)invitationDescriptorId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId publicKey:(nullable NSString *)publicKey secretKey:(nullable NSData *)secretKey {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _invitationDescriptorId = invitationDescriptorId;
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _publicKey = publicKey;
        _secretKey = secretKey;
    }
    return self;
}

@end
