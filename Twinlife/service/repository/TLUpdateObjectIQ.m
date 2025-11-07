/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update object IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3bfed52d-0173-4f0d-bfd9-f5d63454ca59",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"updateOptions", "type": "int"}
 *     {"name":"objectId", "type": "uuid"}
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
// Implementation: TLUpdateObjectIQSerializer
//

@implementation TLUpdateObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateObjectIQ *updateObjectIQ = (TLUpdateObjectIQ *)object;
    [encoder writeInt:updateObjectIQ.updateOptions];
    [encoder writeUUID:updateObjectIQ.objectId];
    [encoder writeUUID:updateObjectIQ.objectSchemaId];
    [encoder writeInt:updateObjectIQ.objectSchemaVersion];
    [encoder writeOptionalUUID:updateObjectIQ.objectKey];
    [encoder writeString:updateObjectIQ.objectData];
    if (!updateObjectIQ.exclusiveContents) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)updateObjectIQ.exclusiveContents.count];
        for (NSString *content in updateObjectIQ.exclusiveContents) {
            [encoder writeString:content];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLUpdateObjectIQ
//

@implementation TLUpdateObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId updateOptions:(int)updateOptions objectId:(nonnull NSUUID *)objectId objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _updateOptions = updateOptions;
        _objectId = objectId;
        _objectSchemaId = objectSchemaId;
        _objectSchemaVersion = objectSchemaVersion;
        _objectKey = objectKey;
        _objectData = objectData;
        _exclusiveContents = exclusiveContents;
    }
    return self;
}

@end
