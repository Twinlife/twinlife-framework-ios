/*
 *  Copyright (c) 2021-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPushGeolocationIQ.h"
#import "TLGeolocationDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushGeolocation IQ.
 * <p>
 * Schema version 3
 *  Date: 2026/04/29
 *
 * <pre>
 * {
 *  "schemaId":"7a9772c3-5f99-468d-87af-d67fdb181295",
 *  "schemaVersion":"3",
 *  "type":"record",
 *  "name":"PushGeolocationIQ",
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
 *     {"name":"longitude", "type":"double"}
 *     {"name":"latitude", "type":"double"}
 *     {"name":"altitude", "type":"double"}
 *     {"name":"mapLongitudeDelta", "type":"double"}
 *     {"name":"mapLatitudeDelta", "type":"double"}
 *     {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 * * </pre>
 * <p>
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"7a9772c3-5f99-468d-87af-d67fdb181295",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushGeolocationIQ",
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
 *     {"name":"longitude", "type":"double"}
 *     {"name":"latitude", "type":"double"}
 *     {"name":"altitude", "type":"double"}
 *     {"name":"mapLongitudeDelta", "type":"double"}
 *     {"name":"mapLatitudeDelta", "type":"double"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushGeolocationIQSerializer_3
//

@implementation TLPushGeolocationIQSerializer_3

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushGeolocationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushGeolocationIQ *pushGeolocationIQ = (TLPushGeolocationIQ *)object;
    TLGeolocationDescriptor *geolocationDescriptor = pushGeolocationIQ.geolocationDescriptor;
    TLDescriptorId *descriptorId = geolocationDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:geolocationDescriptor.sendTo];
    TLDescriptorId *replyTo = geolocationDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:geolocationDescriptor.createdTimestamp];
    [encoder writeLong:geolocationDescriptor.sentTimestamp];
    [encoder writeLong:geolocationDescriptor.expireTimeout];
    [encoder writeDouble:geolocationDescriptor.longitude];
    [encoder writeDouble:geolocationDescriptor.latitude];
    [encoder writeDouble:geolocationDescriptor.altitude];
    [encoder writeDouble:geolocationDescriptor.mapLongitudeDelta];
    [encoder writeDouble:geolocationDescriptor.mapLatitudeDelta];
    [encoder writeBoolean:geolocationDescriptor.copyAllowed];
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

    double longitude = [decoder readDouble];
    double latitude = [decoder readDouble];
    double altitude = [decoder readDouble];
    double mapLongitudeDelta = [decoder readDouble];
    double mapLatitudeDelta = [decoder readDouble];
    BOOL copyAllowed = [decoder readBoolean];

    TLGeolocationDescriptor *geolocationDescriptor = [[TLGeolocationDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta isValidLocalMap:NO localMapPath:nil expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp copyAllowed:copyAllowed];
    return [[TLPushGeolocationIQ alloc] initWithSerializer:self requestId:requestId geolocationDescriptor:geolocationDescriptor];
}

@end


//
// Implementation: TLPushGeolocationIQSerializer_2
//

@implementation TLPushGeolocationIQSerializer_2

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushGeolocationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushGeolocationIQ *pushGeolocationIQ = (TLPushGeolocationIQ *)object;
    TLGeolocationDescriptor *geolocationDescriptor = pushGeolocationIQ.geolocationDescriptor;
    TLDescriptorId *descriptorId = geolocationDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:geolocationDescriptor.sendTo];
    TLDescriptorId *replyTo = geolocationDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:geolocationDescriptor.createdTimestamp];
    [encoder writeLong:geolocationDescriptor.sentTimestamp];
    [encoder writeLong:geolocationDescriptor.expireTimeout];
    [encoder writeDouble:geolocationDescriptor.longitude];
    [encoder writeDouble:geolocationDescriptor.latitude];
    [encoder writeDouble:geolocationDescriptor.altitude];
    [encoder writeDouble:geolocationDescriptor.mapLongitudeDelta];
    [encoder writeDouble:geolocationDescriptor.mapLatitudeDelta];
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

    double longitude = [decoder readDouble];
    double latitude = [decoder readDouble];
    double altitude = [decoder readDouble];
    double mapLongitudeDelta = [decoder readDouble];
    double mapLatitudeDelta = [decoder readDouble];

    TLGeolocationDescriptor *geolocationDescriptor = [[TLGeolocationDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta isValidLocalMap:NO localMapPath:nil expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp copyAllowed:NO];
    return [[TLPushGeolocationIQ alloc] initWithSerializer:self requestId:requestId geolocationDescriptor:geolocationDescriptor];
}

@end

//
// Implementation: TLPushGeolocationIQ
//

@implementation TLPushGeolocationIQ

static NSString * const SCHEMA_ID = @"7a9772c3-5f99-468d-87af-d67fdb181295";
static TLPushGeolocationIQSerializer_3 *IQ_PUSH_GEOLOCATION_SERIALIZER_3;
static TLPushGeolocationIQSerializer_2 *IQ_PUSH_GEOLOCATION_SERIALIZER_2;
static const int IQ_PUSH_GEOLOCATION_SCHEMA_VERSION_3 = 3;
static const int IQ_PUSH_GEOLOCATION_SCHEMA_VERSION_2 = 2;

+ (void)initialize {

    IQ_PUSH_GEOLOCATION_SERIALIZER_3 = [[TLPushGeolocationIQSerializer_3 alloc] initWithSchema:SCHEMA_ID schemaVersion:IQ_PUSH_GEOLOCATION_SCHEMA_VERSION_3];

    IQ_PUSH_GEOLOCATION_SERIALIZER_2 = [[TLPushGeolocationIQSerializer_2 alloc] initWithSchema:SCHEMA_ID schemaVersion:IQ_PUSH_GEOLOCATION_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_GEOLOCATION_SERIALIZER_3.schemaId;
}

+ (int)SCHEMA_VERSION_3 {

    return IQ_PUSH_GEOLOCATION_SERIALIZER_3.schemaVersion;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_PUSH_GEOLOCATION_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3 {
    
    return IQ_PUSH_GEOLOCATION_SERIALIZER_3;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_PUSH_GEOLOCATION_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId geolocationDescriptor:(nonnull TLGeolocationDescriptor *)geolocationDescriptor {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _geolocationDescriptor = geolocationDescriptor;
    }
    return self;
}

@end
