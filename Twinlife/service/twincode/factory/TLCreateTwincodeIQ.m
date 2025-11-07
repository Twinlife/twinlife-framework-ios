/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create twincode IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"8184d22a-980c-40a3-90c3-02ff4732e7b9",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"CreateTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"createOptions", "type": "int"}
 *     {"name":"factoryAttributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]}
 *     {"name":"inboundAttributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]}
 *     {"name":"outboundAttributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]}
 *     {"name":"switchAttributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]},
 *     {"name":"schemaId", [null, "uuid"]}
 *  ]
 * }
 * </pre>
 * Schema version 1 (REMOVED 2024-02-02 after 22.x)
 */

//
// Implementation: TLCreateTwincodeIQSerializer
//

@implementation TLCreateTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateTwincodeIQ *createTwincodeIQ = (TLCreateTwincodeIQ *)object;
    [encoder writeInt:createTwincodeIQ.createOptions];
    [self serializeWithEncoder:encoder attributes:createTwincodeIQ.factoryAttributes];
    [self serializeWithEncoder:encoder attributes:createTwincodeIQ.inboundAttributes];
    [self serializeWithEncoder:encoder attributes:createTwincodeIQ.outboundAttributes];
    [self serializeWithEncoder:encoder attributes:createTwincodeIQ.switchAttributes];
    [encoder writeOptionalUUID:createTwincodeIQ.twincodeSchemaId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateTwincodeIQ
//

@implementation TLCreateTwincodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions factoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes switchAttributes:(nullable NSArray<TLAttributeNameValue *> *)switchAttributes twincodeSchemaId:(nullable NSUUID *)twincodeSchemaId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _createOptions = createOptions;
        _factoryAttributes = factoryAttributes;
        _inboundAttributes = inboundAttributes;
        _outboundAttributes = outboundAttributes;
        _switchAttributes = switchAttributes;
        _twincodeSchemaId = twincodeSchemaId;
    }
    return self;
}

@end
