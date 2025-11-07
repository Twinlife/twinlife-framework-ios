/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateGeolocationIQ.h"
#import "TLOnPushObjectIQ.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * UpdateGeolocation IQ.
 * <p>
 * Schema version 1
 *  Date: 2024/06/17
 *
 * <pre>
 * {
 *  "schemaId":"92790026-71f3-4702-b8ca-e9d8ce5a3f4d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushGeolocationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"updatedTimestamp", "type":"long"}
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
// Implementation: TLUpdateGeolocationIQSerializer
//

@implementation TLUpdateGeolocationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateGeolocationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateGeolocationIQ *updateGeolocationIQ = (TLUpdateGeolocationIQ *)object;
    [encoder writeLong:updateGeolocationIQ.updatedTimestamp];
    [encoder writeDouble:updateGeolocationIQ.longitude];
    [encoder writeDouble:updateGeolocationIQ.latitude];
    [encoder writeDouble:updateGeolocationIQ.altitude];
    [encoder writeDouble:updateGeolocationIQ.mapLongitudeDelta];
    [encoder writeDouble:updateGeolocationIQ.mapLatitudeDelta];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    int64_t requestId = [decoder readLong];
    int64_t updatedTimestamp = [decoder readLong];
    double longitude = [decoder readDouble];
    double latitude = [decoder readDouble];
    double altitude = [decoder readDouble];
    double mapLongitudeDelta = [decoder readDouble];
    double mapLatitudeDelta = [decoder readDouble];

    return [[TLUpdateGeolocationIQ alloc] initWithSerializer:self requestId:requestId updatedTimestamp:updatedTimestamp longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta];
}

@end

//
// Implementation: TLUpdateGeolocationIQ
//

@implementation TLUpdateGeolocationIQ

static TLUpdateGeolocationIQSerializer *IQ_UPDATE_GEOLOCATION_SERIALIZER_1;
static const int IQ_UPDATE_GEOLOCATION_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_UPDATE_GEOLOCATION_SERIALIZER_1 = [[TLUpdateGeolocationIQSerializer alloc] initWithSchema:@"92790026-71f3-4702-b8ca-e9d8ce5a3f4d" schemaVersion:IQ_UPDATE_GEOLOCATION_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_UPDATE_GEOLOCATION_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_UPDATE_GEOLOCATION_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_UPDATE_GEOLOCATION_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId updatedTimestamp:(int64_t)updatedTimestamp longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _updatedTimestamp = updatedTimestamp;
        _longitude = longitude;
        _latitude = latitude;
        _altitude = altitude;
        _mapLongitudeDelta = mapLongitudeDelta;
        _mapLatitudeDelta = mapLatitudeDelta;
    }
    return self;
}

@end

/**
 * OnUpdateGeolocation IQ.
 *
 * Schema version 1
 *  Date: 2024/06/07
 *
 * <pre>
 * {
 *  "schemaId":"09466194-bd50-4c1f-a59e-62a03cecba9e",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateGeolocationIQ",
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
// Implementation: TLOnPushTwincodeIQ
//

@implementation TLOnUpdateGeolocationIQ

static TLOnPushIQSerializer *IQ_ON_UPDATE_GEOLOCATION_SERIALIZER_1;
static const int IQ_ON_UPDATE_GEOLOCATION_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_UPDATE_GEOLOCATION_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"09466194-bd50-4c1f-a59e-62a03cecba9e" schemaVersion:IQ_ON_UPDATE_GEOLOCATION_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_UPDATE_GEOLOCATION_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_UPDATE_GEOLOCATION_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_UPDATE_GEOLOCATION_SERIALIZER_1;
}

@end
