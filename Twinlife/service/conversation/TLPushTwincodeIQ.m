/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushTwincodeIQ.h"
#import "TLTwincodeDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushTwincode IQ.
 * Schema version 3
 *  Date: 2024/07/26
 *
 * <pre>
 * {
 *  "schemaId":"72863c61-c0a9-437b-8b88-3b78354e54b8",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"PushTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"sendToTwincodeOutboundId", "type":["null", "UUID"]},
 *     {"name":"replyTo", "type":["null", {
 *         {"name":"twincodeOutboundId", "type":"uuid"},
 *         {"name":"sequenceId", "type":"long"}
 *     }},
 *     {"name":"createdTimestamp", "type":"long"}
 *     {"name":"sentTimestamp", "type":"long"}
 *     {"name":"expireTimeout", "type":"long"}
 *     {"name":"twincode", "type":"UUID"}
 *     {"name":"schemaId", "type":"UUID"}
 *     {"name":"copyAllowed", "type":"boolean"}
 *     {"name":"publicKey", "type":[null, "String"]}
 *  ]
 * }
 * </pre>
 * <p>
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"72863c61-c0a9-437b-8b88-3b78354e54b8",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"sendToTwincodeOutboundId", "type":["null", "UUID"]},
 *     {"name":"replyTo", "type":["null", {
 *         {"name":"twincodeOutboundId", "type":"uuid"},
 *         {"name":"sequenceId", "type":"long"}
 *     }},
 *     {"name":"createdTimestamp", "type":"long"}
 *     {"name":"sentTimestamp", "type":"long"}
 *     {"name":"expireTimeout", "type":"long"}
 *     {"name":"twincode", "type":"UUID"}
 *     {"name":"schemaId", "type":"UUID"}
 *     {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLPushTwincodeIQSerializer_3
//

@implementation TLPushTwincodeIQSerializer_3

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushTwincodeIQ *pushTwincodeIQ = (TLPushTwincodeIQ *)object;
    TLTwincodeDescriptor *twincodeDescriptor = pushTwincodeIQ.twincodeDescriptor;
    TLDescriptorId *descriptorId = twincodeDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:twincodeDescriptor.sendTo];
    TLDescriptorId *replyTo = twincodeDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:twincodeDescriptor.createdTimestamp];
    [encoder writeLong:twincodeDescriptor.sentTimestamp];
    [encoder writeLong:twincodeDescriptor.expireTimeout];
    [encoder writeUUID:twincodeDescriptor.twincodeId];
    [encoder writeUUID:twincodeDescriptor.schemaId];
    [encoder writeBoolean:twincodeDescriptor.copyAllowed];
    [encoder writeOptionalString:twincodeDescriptor.publicKey];
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

    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *schemaId = [decoder readUUID];
    BOOL copyAllowed = [decoder readBoolean];
    NSString *publicKey = [decoder readOptionalString];
    TLTwincodeDescriptor *twincodeDescriptor = [[TLTwincodeDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo twincodeId:twincodeId schemaId:schemaId publicKey:publicKey copyAllowed:copyAllowed  expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    return [[TLPushTwincodeIQ alloc] initWithSerializer:self requestId:requestId twincodeDescriptor:twincodeDescriptor];
}

@end

//
// Implementation: TLPushTwincodeIQSerializer_2
//

@implementation TLPushTwincodeIQSerializer_2

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushTwincodeIQ *pushTwincodeIQ = (TLPushTwincodeIQ *)object;
    TLTwincodeDescriptor *twincodeDescriptor = pushTwincodeIQ.twincodeDescriptor;
    TLDescriptorId *descriptorId = twincodeDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:twincodeDescriptor.sendTo];
    TLDescriptorId *replyTo = twincodeDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:twincodeDescriptor.createdTimestamp];
    [encoder writeLong:twincodeDescriptor.sentTimestamp];
    [encoder writeLong:twincodeDescriptor.expireTimeout];
    [encoder writeUUID:twincodeDescriptor.twincodeId];
    [encoder writeUUID:twincodeDescriptor.schemaId];
    [encoder writeBoolean:twincodeDescriptor.copyAllowed];
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

    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *schemaId = [decoder readUUID];
    BOOL copyAllowed = [decoder readBoolean];
    TLTwincodeDescriptor *twincodeDescriptor = [[TLTwincodeDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo twincodeId:twincodeId schemaId:schemaId publicKey:nil copyAllowed:copyAllowed  expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    return [[TLPushTwincodeIQ alloc] initWithSerializer:self requestId:requestId twincodeDescriptor:twincodeDescriptor];
}

@end

//
// Implementation: TLPushTwincodeIQ
//

@implementation TLPushTwincodeIQ

static TLPushTwincodeIQSerializer_3 *IQ_PUSH_TWINCODE_SERIALIZER_3;
static const int IQ_PUSH_TWINCODE_SCHEMA_VERSION_3 = 3;

static TLPushTwincodeIQSerializer_2 *IQ_PUSH_TWINCODE_SERIALIZER_2;
static const int IQ_PUSH_TWINCODE_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_PUSH_TWINCODE_SERIALIZER_3 = [[TLPushTwincodeIQSerializer_3 alloc] initWithSchema:@"72863c61-c0a9-437b-8b88-3b78354e54b8" schemaVersion:IQ_PUSH_TWINCODE_SCHEMA_VERSION_3];
    IQ_PUSH_TWINCODE_SERIALIZER_2 = [[TLPushTwincodeIQSerializer_2 alloc] initWithSchema:@"72863c61-c0a9-437b-8b88-3b78354e54b8" schemaVersion:IQ_PUSH_TWINCODE_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_TWINCODE_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_3 {

    return IQ_PUSH_TWINCODE_SERIALIZER_3.schemaVersion;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_PUSH_TWINCODE_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3 {
    
    return IQ_PUSH_TWINCODE_SERIALIZER_3;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_PUSH_TWINCODE_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeDescriptor:(nonnull TLTwincodeDescriptor *)twincodeDescriptor {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeDescriptor = twincodeDescriptor;
    }
    return self;
}

@end
