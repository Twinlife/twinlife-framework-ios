/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateTimestampIQ.h"
#import "TLOnPushObjectIQ.h"
#import "TLSerializerFactory.h"
#import "TLDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * UpdateTimestampIQ IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/06/17
 *
 * <pre>
 * {
 *  "schemaId":"b814c454-299b-48c0-aa40-19afa72ccef8",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"UpdateTimestampIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"type", ["READ", "DELETE", "PEER_DELETE"]}
 *     {"name":"timestamp", "type":"long"}
 * }
 *
 * </pre>
 */

//
// Implementation: TLUpdateTimestampIQSerializer
//

@implementation TLUpdateTimestampIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateTimestampIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateTimestampIQ *updateTimestampIQ = (TLUpdateTimestampIQ *)object;
    [encoder writeUUID:updateTimestampIQ.descriptorId.twincodeOutboundId];
    [encoder writeLong:updateTimestampIQ.descriptorId.sequenceId];
    switch (updateTimestampIQ.timestampType) {
        case TLUpdateDescriptorTimestampTypeRead:
            [encoder writeEnum:0];
            break;

        case TLUpdateDescriptorTimestampTypeDelete:
            [encoder writeEnum:1];
            break;

        case TLUpdateDescriptorTimestampTypePeerDelete:
            [encoder writeEnum:2];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
            break;
    }
    [encoder writeLong:updateTimestampIQ.timestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    TLUpdateDescriptorTimestampType timestampType;
    switch ([decoder readEnum]) {
        case 0:
            timestampType = TLUpdateDescriptorTimestampTypeRead;
            break;

        case 1:
            timestampType = TLUpdateDescriptorTimestampTypeDelete;
            break;

        case 2:
            timestampType = TLUpdateDescriptorTimestampTypePeerDelete;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
            break;
    }
    int64_t timestamp = [decoder readLong];

    return [[TLUpdateTimestampIQ alloc] initWithSerializer:self requestId:requestId descriptorId:descriptorId timestampType:timestampType timestamp:timestamp];
}

@end

//
// Implementation: TLUpdateTimestampIQ
//

@implementation TLUpdateTimestampIQ

static TLUpdateTimestampIQSerializer *IQ_UPDATE_TIMESTAMP_SERIALIZER_2;
static const int IQ_UPDATE_TIMESTAMP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_UPDATE_TIMESTAMP_SERIALIZER_2 = [[TLUpdateTimestampIQSerializer alloc] initWithSchema:@"b814c454-299b-48c0-aa40-19afa72ccef8" schemaVersion:IQ_UPDATE_TIMESTAMP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_UPDATE_TIMESTAMP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_UPDATE_TIMESTAMP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_UPDATE_TIMESTAMP_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId timestampType:(TLUpdateDescriptorTimestampType)timestampType timestamp:(int64_t)timestamp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _descriptorId = descriptorId;
        _timestampType = timestampType;
        _timestamp = timestamp;
    }
    return self;
}

@end

/**
 * OnUpdateTimestampIQ IQ.
 *
 * Schema version 2
 *  Date: 2024/06/07
 *
 * <pre>
 * {
 *  "schemaId":"87d33c5f-9b9b-49bf-a802-8bd24fb021a6",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnUpdateTimestampIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnUpdateTimestampIQ
//

@implementation TLOnUpdateTimestampIQ

static TLOnPushIQSerializer *IQ_ON_UPDATE_TIMESTAMP_SERIALIZER_2;
static const int IQ_ON_UPDATE_TIMESTAMP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_UPDATE_TIMESTAMP_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"87d33c5f-9b9b-49bf-a802-8bd24fb021a6" schemaVersion:IQ_ON_UPDATE_TIMESTAMP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_UPDATE_TIMESTAMP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_UPDATE_TIMESTAMP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_ON_UPDATE_TIMESTAMP_SERIALIZER_2;
}

@end
