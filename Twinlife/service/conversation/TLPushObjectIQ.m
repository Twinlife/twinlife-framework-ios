/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushObjectIQ.h"
#import "TLObjectDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushObject IQ.
 * <p>
 * Schema version 5
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"26e3a3bd-7db0-4fc5-9857-bbdb2032960e",
 *  "schemaVersion":"5",
 *
 *  "type":"record",
 *  "name":"PushObjectIQ",
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
 *     {"name":"object", "type":"Object"}
 *     {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushObjectIQSerializer
//

@implementation TLPushObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushObjectIQ *pushObjectIQ = (TLPushObjectIQ *)object;
    TLObjectDescriptor *objectDescriptor = pushObjectIQ.objectDescriptor;
    TLDescriptorId *descriptorId = objectDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:objectDescriptor.sendTo];
    TLDescriptorId *replyTo = objectDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:objectDescriptor.createdTimestamp];
    [encoder writeLong:objectDescriptor.sentTimestamp];
    [encoder writeLong:objectDescriptor.expireTimeout];
    [objectDescriptor serializeWithEncoder:encoder];
    [encoder writeBoolean:objectDescriptor.copyAllowed];
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

    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    TLSerializer *serializer = [serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
    if (!serializer) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSString *message = [decoder readString];

    BOOL copyAllowed = [decoder readBoolean];
    TLObjectDescriptor *objectDescriptor = [[TLObjectDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo message:message copyAllowed:copyAllowed  expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    return [[TLPushObjectIQ alloc] initWithSerializer:self requestId:requestId objectDescriptor:objectDescriptor];
}

@end

//
// Implementation: TLPushObjectIQ
//

@implementation TLPushObjectIQ

static TLPushObjectIQSerializer *IQ_PUSH_OBJECT_SERIALIZER_5;
static const int IQ_PUSH_OBJECT_SCHEMA_VERSION_5 = 5;

+ (void)initialize {
    
    IQ_PUSH_OBJECT_SERIALIZER_5 = [[TLPushObjectIQSerializer alloc] initWithSchema:@"26e3a3bd-7db0-4fc5-9857-bbdb2032960e" schemaVersion:IQ_PUSH_OBJECT_SCHEMA_VERSION_5];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_OBJECT_SERIALIZER_5.schemaId;
}

+ (int)SCHEMA_VERSION_5 {

    return IQ_PUSH_OBJECT_SERIALIZER_5.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_5 {
    
    return IQ_PUSH_OBJECT_SERIALIZER_5;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _objectDescriptor = objectDescriptor;
    }
    return self;
}

@end
