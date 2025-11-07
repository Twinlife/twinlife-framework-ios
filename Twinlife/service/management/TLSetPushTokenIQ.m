/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSetPushTokenIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Set push token request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3c1115d7-ed74-4445-b689-63e9c10eb50c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SetPushTokenIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"environmentId", "type":"uuid"}
 *     {"name":"pushVariant", "type":"string"},
 *     {"name":"pushToken", "type":"string"},
 *     {"name":"pushRemoteToken", [null, "type":"string"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSetPushTokenIQSerializer
//

@implementation TLSetPushTokenIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSetPushTokenIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSetPushTokenIQ *validateConfigurationIQ = (TLSetPushTokenIQ *)object;
    [encoder writeUUID:validateConfigurationIQ.environmentId];
    [encoder writeString:validateConfigurationIQ.pushVariant];
    [encoder writeString:validateConfigurationIQ.pushToken];
    [encoder writeOptionalString:validateConfigurationIQ.pushRemoteToken];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLSetPushTokenIQ
//

@implementation TLSetPushTokenIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId environmentId:(nonnull NSUUID *)environmentId pushVariant:(nonnull NSString *)pushVariant pushToken:(nonnull NSString *)pushToken pushRemoteToken:(nullable NSString *)pushRemoteToken {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _environmentId = environmentId;
        _pushVariant = pushVariant;
        _pushToken = pushToken;
        _pushRemoteToken = pushRemoteToken;
    }
    return self;
}

@end
