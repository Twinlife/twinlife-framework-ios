/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLGeolocationDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLTwinlifeImpl.h"

/*
 * <pre>
 *
 * Schema version 2
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"753da853-a54d-4cc5-b8b6-dec3855d8e08",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"GeolocationDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.4"
 *  "fields":
 *  [
 *   {"name":"longitude", "type":"double"}
 *   {"name":"latitude", "type":"double"}
 *   {"name":"altitude", "type":"double"}
 *   {"name":"mapLongitudeDelta", "type":"double"}
 *   {"name":"mapLatitudeDelta", "type":"double"}
 *   {"name":"updated", "type":"boolean"}
 *   {"name":"localMapPath", "type": ["null", "string"]}
 *  ]
 * }
 *
 * Schema version 1
 *  Date: 2019/02/14
 *
 * {
 *  "schemaId":"753da853-a54d-4cc5-b8b6-dec3855d8e08",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GeolocationDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"longitude", "type":"double"}
 *   {"name":"latitude", "type":"double"}
 *   {"name":"altitude", "type":"double"}
 *   {"name":"mapLongitudeDelta", "type":"double"}
 *   {"name":"mapLatitudeDelta", "type":"double"}
 *   {"name":"updated", "type":"boolean"}
 *   {"name":"localMapPath", "type": ["null", "string"]}
 *  ]
 * }
 *
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLGeolocationDescriptorSerializer
//

static NSUUID *GEOLOCATION_DESCRIPTOR_SCHEMA_ID = nil;
static const int GEOLOCATION_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static const int GEOLOCATION_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLGeolocationDescriptorSerializer_2 *GEOLOCATION_DESCRIPTOR_SERIALIZER_2 = nil;
static TLSerializer *GEOLOCATION_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLGeolocationDescriptorSerializer_2"

@implementation TLGeolocationDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLGeolocationDescriptor.SCHEMA_ID schemaVersion:TLGeolocationDescriptor.SCHEMA_VERSION_2 class:[TLGeolocationDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)object;
    [encoder writeDouble:geolocationDescriptor.longitude];
    [encoder writeDouble:geolocationDescriptor.latitude];
    [encoder writeDouble:geolocationDescriptor.altitude];
    [encoder writeDouble:geolocationDescriptor.mapLongitudeDelta];
    [encoder writeDouble:geolocationDescriptor.mapLatitudeDelta];
    [encoder writeBoolean:geolocationDescriptor.isValidLocalMap];
    [encoder writeOptionalString:geolocationDescriptor.localMapPath];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    
    int64_t expireTimeout = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];

    double longitude = [decoder readDouble];
    double latitude = [decoder readDouble];
    double altitude = [decoder readDouble];
    double mapLongitudeDelta = [decoder readDouble];
    double mapLatitudeDelta = [decoder readDouble];
    BOOL isValidLocalMap = [decoder readBoolean];
    NSString *localMapPath = [decoder readOptionalString];

    return [[TLGeolocationDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta isValidLocalMap:isValidLocalMap localMapPath:localMapPath expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:0];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLGeolocationDescriptorSerializer_1"

@implementation TLGeolocationDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLGeolocationDescriptor.SCHEMA_ID schemaVersion:TLGeolocationDescriptor.SCHEMA_VERSION_1 class:[TLGeolocationDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)object;
    [encoder writeDouble:geolocationDescriptor.longitude];
    [encoder writeDouble:geolocationDescriptor.latitude];
    [encoder writeDouble:geolocationDescriptor.altitude];
    [encoder writeDouble:geolocationDescriptor.mapLongitudeDelta];
    [encoder writeDouble:geolocationDescriptor.mapLatitudeDelta];
    [encoder writeBoolean:geolocationDescriptor.isValidLocalMap];
    [encoder writeOptionalString:geolocationDescriptor.localMapPath];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    double longitude = [decoder readDouble];
    double latitude = [decoder readDouble];
    double altitude = [decoder readDouble];
    double mapLongitudeDelta = [decoder readDouble];
    double mapLatitudeDelta = [decoder readDouble];
    BOOL isValidLocalMap = [decoder readBoolean];
    NSString *localMapPath = [decoder readOptionalString];

    return [[TLGeolocationDescriptor alloc] initWithDescriptor:descriptor longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta isValidLocalMap:isValidLocalMap localMapPath:localMapPath];
}

@end

//
// Implementation: TLGeolocationDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLGeolocationDescriptor"

@implementation TLGeolocationDescriptor

+ (void)initialize {
    
    GEOLOCATION_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"753da853-a54d-4cc5-b8b6-dec3855d8e08"];
    GEOLOCATION_DESCRIPTOR_SERIALIZER_2 = [[TLGeolocationDescriptorSerializer_2 alloc] init];
    GEOLOCATION_DESCRIPTOR_SERIALIZER_1 = [[TLGeolocationDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return GEOLOCATION_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_2 {
    
    return GEOLOCATION_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return GEOLOCATION_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLGeolocationDescriptorSerializer_2 *)SERIALIZER_2 {
    
    return GEOLOCATION_DESCRIPTOR_SERIALIZER_2;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return GEOLOCATION_DESCRIPTOR_SERIALIZER_1;
}

#pragma mark - NSObject

- (nonnull NSString *)description {
    
    NSMutableString *string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGeolocationDescriptor\n"];
    [self appendTo:string];
    [string appendFormat:@" longitude: %f\n", self.longitude];
    [string appendFormat:@" latitude: %f\n", self.latitude];
    [string appendFormat:@" altitude: %f\n", self.altitude];
    [string appendFormat:@" mapLongitudeDelta: %f\n", self.mapLongitudeDelta];
    [string appendFormat:@" mapLatitudeDelta: %f\n", self.mapLatitudeDelta];
    [string appendFormat:@" localMapPath: %@\n", self.localMapPath];
    [string appendFormat:@" isValidLocalMap: %d\n", self.isValidLocalMap];
    return string;
}

#pragma mark - TLDescriptor ()

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeGeolocationDescriptor;
}

- (nullable NSURL *)getURL {
    
    if (!self.localMapPath) {
        return nil;
    } else {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
        return [groupURL URLByAppendingPathComponent:self.localMapPath];
    }
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
}

#pragma mark - TLGeolocationDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ longitude: %f latitude: %f altitude: %f mapLongitudeDelta: %f mapLatitudeDelta: %f expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, longitude, latitude, altitude, mapLongitudeDelta, mapLatitudeDelta, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    if (self) {
        _longitude = longitude;
        _latitude = latitude;
        _altitude = altitude;
        _mapLongitudeDelta = mapLongitudeDelta;
        _mapLatitudeDelta = mapLatitudeDelta;
        _localMapPath = nil;
        _isValidLocalMap = NO;
    }
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta isValidLocalMap:(BOOL)isValidLocalMap localMapPath:(nullable NSString *)localMapPath expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld sendTo: %@ replyTo: %@ longitude: %f latitude: %f altitude: %f mapLongitudeDelta: %f mapLatitudeDelta: %f expireTimeout: %lld createdTimestamp: %lld sentTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, sendTo, replyTo, longitude, latitude, altitude, mapLongitudeDelta, mapLatitudeDelta, expireTimeout, createdTimestamp, sentTimestamp);
    
    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _longitude = longitude;
        _latitude = latitude;
        _altitude = altitude;
        _mapLongitudeDelta = mapLongitudeDelta;
        _mapLatitudeDelta = mapLatitudeDelta;
        _localMapPath = localMapPath;
        _isValidLocalMap = isValidLocalMap;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo descriptor:(nonnull TLGeolocationDescriptor *)descriptor expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ descriptor: %@ expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, descriptor, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil expireTimeout:expireTimeout];
    
    if (self) {
        _longitude = descriptor.longitude;
        _latitude = descriptor.latitude;
        _altitude = descriptor.altitude;
        _mapLongitudeDelta = descriptor.mapLongitudeDelta;
        _mapLatitudeDelta = descriptor.mapLatitudeDelta;
        _localMapPath = descriptor.localMapPath;
        _isValidLocalMap = descriptor.isValidLocalMap;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta isValidLocalMap:(BOOL)isValidLocalMap localMapPath:(nullable NSString *)localMapPath {
    DDLogVerbose(@"%@ initWithDescriptor: %@ longitude: %f latitude: %f altitude: %f mapLongitudeDelta: %f mapLatitudeDelta: %f isValidLocalMap: %d localMapPath: %@", LOG_TAG, descriptor, longitude, latitude, altitude, mapLongitudeDelta, mapLatitudeDelta, isValidLocalMap, localMapPath);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _longitude = longitude;
        _latitude = latitude;
        _altitude = altitude;
        _mapLongitudeDelta = mapLongitudeDelta;
        _mapLatitudeDelta = mapLatitudeDelta;
        _localMapPath = localMapPath;
        _isValidLocalMap = isValidLocalMap;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@", LOG_TAG, descriptorId, conversationId, creationDate, flags, content);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if (self) {
        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];

        _longitude = [TLDescriptor extractDoubleWithArgs:args position:0 defaultValue:0.0];
        _latitude = [TLDescriptor extractDoubleWithArgs:args position:1 defaultValue:0.0];
        _altitude = [TLDescriptor extractDoubleWithArgs:args position:2 defaultValue:0.0];
        _mapLongitudeDelta = [TLDescriptor extractDoubleWithArgs:args position:3 defaultValue:0.0];
        _mapLatitudeDelta = [TLDescriptor extractDoubleWithArgs:args position:4 defaultValue:0.0];
        _localMapPath = [TLDescriptor extractStringWithArgs:args position:5 defaultValue:nil];
        _isValidLocalMap = (flags & DESCRIPTOR_FLAG_UPDATED) != 0;
    }
    return self;
}

/// Used to forward a descriptor (see createForwardWithDescriptorId).
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo expireTimeout:(int64_t)expireTimeout descriptor:(nonnull TLGeolocationDescriptor *)descriptor {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@", LOG_TAG, descriptorId, conversationId, sendTo);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil expireTimeout:expireTimeout];
    
    if (self) {
        _longitude = descriptor.longitude;
        _latitude = descriptor.latitude;
        _altitude = descriptor.altitude;
        _mapLatitudeDelta = descriptor.mapLatitudeDelta;
        _mapLongitudeDelta = descriptor.mapLongitudeDelta;
        _isValidLocalMap = NO;
        _localMapPath = nil;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%f\n%f\n%f\n%f\n%f\n%@", self.longitude, self.latitude, self.altitude, self.mapLongitudeDelta, self.mapLatitudeDelta, self.localMapPath];
}

- (int)flags {
    
    return (self.isValidLocalMap ? DESCRIPTOR_FLAG_UPDATED : 0);
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendGeolocation;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLGeolocationDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo expireTimeout:expireTimeout descriptor:self];
}

- (BOOL)updateWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor {
    DDLogVerbose(@"%@ updateWithDescriptor: %@", LOG_TAG, descriptor);
    
    BOOL updated = NO;
    if (descriptor.longitude != self.longitude) {
        self.longitude = descriptor.longitude;
        updated = YES;
    }
    if (descriptor.latitude != self.latitude) {
        self.latitude = descriptor.latitude;
        updated = YES;
    }
    if (descriptor.altitude != self.altitude) {
        self.altitude = descriptor.altitude;
        updated = YES;
    }
    if (descriptor.mapLongitudeDelta != self.mapLongitudeDelta) {
        self.mapLongitudeDelta = descriptor.mapLongitudeDelta;
        updated = YES;
    }
    if (descriptor.mapLatitudeDelta != self.mapLatitudeDelta) {
        self.mapLatitudeDelta = descriptor.mapLatitudeDelta;
        updated = YES;
    }
    if (updated) {
        self.isValidLocalMap = NO;
    }
    return updated;
}

@end
