/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create object IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"cc1de051-04c9-49c2-827d-2d8c8545ff41",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"createOptions", "type": "int"}
 *     {"name":"objectSchemaId", "type": "uuid"}
 *     {"name":"objectSchemaVersion", "type": "int"}
 *     {"name":"objectKey", "type": [null, "uuid"]}
 *     {"name":"data", "type": "string"}
 *     {"name":"exclusiveContents", [
 *      {"name":"name", "type": "string"}
 *     ]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLCreateObjectIQSerializer
//

@implementation TLCreateObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateObjectIQ *createObjectIQ = (TLCreateObjectIQ *)object;
    [encoder writeInt:createObjectIQ.createOptions];
    [encoder writeUUID:createObjectIQ.objectSchemaId];
    [encoder writeInt:createObjectIQ.objectSchemaVersion];
    [encoder writeOptionalUUID:createObjectIQ.objectKey];
    [encoder writeString:createObjectIQ.objectData];
    if (!createObjectIQ.exclusiveContents) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)createObjectIQ.exclusiveContents.count];
        for (NSString *content in createObjectIQ.exclusiveContents) {
            [encoder writeString:content];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateObjectIQ
//

@implementation TLCreateObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _createOptions = createOptions;
        _objectSchemaId = objectSchemaId;
        _objectSchemaVersion = objectSchemaVersion;
        _objectKey = objectKey;
        _objectData = objectData;
        _exclusiveContents = exclusiveContents;
    }
    return self;
}

@end
