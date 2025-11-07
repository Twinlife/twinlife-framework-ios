/*
 *  Copyright (c) 2021-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLValidateConfigurationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Validate configuration IQ.
 *
 * Schema version 1 and version 2
 * <pre>
 * {
 *  "schemaId":"437466BB-B2AC-4A53-9376-BFE263C98220",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ValidateConfigurationIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"int"},
 *     {"name":"environmentId", [null, "type":"uuid"]},
 *     {"name":"pushVariant", [null, "type":"string"]},
 *     {"name":"pushToken", [null, "type":"string"]},
 *     {"name":"pushRemoteToken", [null, "type":"string"]},
 *     {"name":"serviceCount", "type":"int"}, [
 *        {"name":"serviceName", "type":"string"},
 *        {"name":"serviceVersion", "type":"string"}
 *     ]},
 *     {"name":"hardwareBrand", "type":"string"},
 *     {"name":"hardwareModel", "type":"string"},
 *     {"name":"osName", "type":"string"},
 *     {"name":"locale", "type":"string"},
 *     {"name":"capabilities", "type":"string"},
 *     {"name":"configCount", "type":"int"}, [
 *        {"name":"configName", "type":"string"},
 *        {"name":"configValue", "type":"string"}
 *     ]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLValidateConfigurationIQSerializer
//

@implementation TLValidateConfigurationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLValidateConfigurationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLValidateConfigurationIQ *validateConfigurationIQ = (TLValidateConfigurationIQ *)object;
    [encoder writeInt:validateConfigurationIQ.deviceState];
    [encoder writeOptionalUUID:validateConfigurationIQ.environmentId];
    [encoder writeOptionalString:validateConfigurationIQ.pushVariant];
    [encoder writeOptionalString:validateConfigurationIQ.pushToken];
    [encoder writeOptionalString:validateConfigurationIQ.pushRemoteToken];

    [encoder writeInt:(int)validateConfigurationIQ.services.count];
    for (NSString *key in validateConfigurationIQ.services) {
        [encoder writeString:key];
        [encoder writeString:validateConfigurationIQ.services[key]];
    }

    [encoder writeString:@"Apple"];
    [encoder writeString:validateConfigurationIQ.hardwareName];
    [encoder writeString:validateConfigurationIQ.osName];
    [encoder writeString:validateConfigurationIQ.locale];
    [encoder writeString:validateConfigurationIQ.capabilities];

    [encoder writeInt:(int)validateConfigurationIQ.configs.count];
    for (NSString *key in validateConfigurationIQ.configs) {
        [encoder writeString:key];
        [encoder writeString:validateConfigurationIQ.configs[key]];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLValidateConfigurationIQ
//

@implementation TLValidateConfigurationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState environmentId:(nullable NSUUID *)environmentId pushVariant:(nullable NSString *)pushVariant pushToken:(nullable NSString *)pushToken pushRemoteToken:(nullable NSString *)pushRemoteToken services:(nonnull NSDictionary<NSString *, NSString *> *)services hardwareName:(nonnull NSString *)hardwareName osName:(nonnull NSString *)osName locale:(nonnull NSString *)locale capabilities:(nonnull NSString *)capabilities configs:(nonnull NSDictionary<NSString *, NSString *> *)configs {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _deviceState = deviceState;
        _environmentId = environmentId;
        _pushVariant = pushVariant;
        _pushToken = pushToken;
        _pushRemoteToken = pushRemoteToken;
        _services = services;
        _hardwareName = hardwareName;
        _osName = osName;
        _locale = locale;
        _capabilities = capabilities;
        _configs = configs;
    }
    return self;
}

@end
