/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushTransientIQ.h"
#import "TLOnPushIQ.h"
#import "TLSerializerFactory.h"
#import "TLDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushTransient IQ.
 * <p>
 * Schema version 3
 *  Date: 2024/09/10
 *
 * <pre>
 * {
 *  "schemaId":"05617876-8419-4240-9945-08bf4106cb72",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"PushTransientIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields":
 *  [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"createdTimestamp", "type":"long"}
 *     {"name":"sentTimestamp", "type":"long"}
 *     {"name":"flags", "type":"int"}
 *     {"name":"object", "type":"Object"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLPushTransientIQSerializer
//

@implementation TLPushTransientIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushTransientIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushTransientIQ *pushTransientIQ = (TLPushTransientIQ *)object;
    TLTransientObjectDescriptor *descriptor = pushTransientIQ.descriptor;
    [encoder writeUUID:descriptor.descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptor.descriptorId.sequenceId];
    [encoder writeLong:descriptor.createdTimestamp];
    [encoder writeLong:descriptor.sentTimestamp];
    [encoder writeInt:pushTransientIQ.flags];
    [descriptor serializeWithSerializerFactory:serializerFactory encoder:encoder];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t createdTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int flags = [decoder readInt];
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    TLSerializer *serializer = [serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
    if (!serializer) {
        @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }

    NSObject *object = [serializer deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    TLTransientObjectDescriptor *descriptor = [[TLTransientObjectDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId serializer:serializer object:object createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    return [[TLPushTransientIQ alloc] initWithSerializer:self requestId:requestId transientObjectDescriptor:descriptor flags:flags];
}

@end

//
// Implementation: TLPushTransientIQ
//

@implementation TLPushTransientIQ

static TLPushTransientIQSerializer *IQ_PUSH_TRANSIENT_SERIALIZER_3;
static const int IQ_PUSH_TRANSIENT_SCHEMA_VERSION_3 = 3;

+ (void)initialize {
    
    IQ_PUSH_TRANSIENT_SERIALIZER_3 = [[TLPushTransientIQSerializer alloc] initWithSchema:@"05617876-8419-4240-9945-08bf4106cb72" schemaVersion:IQ_PUSH_TRANSIENT_SCHEMA_VERSION_3];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_TRANSIENT_SERIALIZER_3.schemaId;
}

+ (int)SCHEMA_VERSION_3 {

    return IQ_PUSH_TRANSIENT_SERIALIZER_3.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_3 {
    
    return IQ_PUSH_TRANSIENT_SERIALIZER_3;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId transientObjectDescriptor:(nonnull TLTransientObjectDescriptor *)transientObjectDescriptor flags:(int)flags {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _descriptor = transientObjectDescriptor;
        _flags = flags;
    }
    return self;
}

@end

/**
 * PushCommandIQ IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/09/10
 * <pre>
 * {
 *  "schemaId":"e8a69b58-1014-4d3c-9357-8331c19c5f59",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushCommandIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields":
 *  [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"createdTimestamp", "type":"long"}
 *     {"name":"sentTimestamp", "type":"long"}
 *     {"name":"object", "type":"Object"}
 *  ]
 * }
 * </pre>
 */
//
// Implementation: TLOnPushCommandIQ
//

@implementation TLPushCommandIQ

static TLPushTransientIQSerializer *IQ_PUSH_COMMAND_SERIALIZER_2;
static const int IQ_PUSH_COMMAND_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_PUSH_COMMAND_SERIALIZER_2 = [[TLPushTransientIQSerializer alloc] initWithSchema:@"e8a69b58-1014-4d3c-9357-8331c19c5f59" schemaVersion:IQ_PUSH_COMMAND_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_COMMAND_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_PUSH_COMMAND_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_PUSH_COMMAND_SERIALIZER_2;
}

@end

/**
 * OnPushCommand IQ.
 *
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"4453dbf3-1b26-4c13-956c-4b83fc1d0c49",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushCommandIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnPushCommandIQ
//

@implementation TLOnPushCommandIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_TRANSIENT_SERIALIZER_2;
static const int IQ_ON_PUSH_TRANSIENT_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_PUSH_TRANSIENT_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"4453dbf3-1b26-4c13-956c-4b83fc1d0c49" schemaVersion:IQ_ON_PUSH_TRANSIENT_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_TRANSIENT_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_PUSH_TRANSIENT_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_ON_PUSH_TRANSIENT_SERIALIZER_2;
}

@end
