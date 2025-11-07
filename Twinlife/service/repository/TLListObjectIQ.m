/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLListObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * List object IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"7d9baa6c-635e-4bda-b31a-a416322e4eec",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ListObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"objectSchemaId", "type": "uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLListObjectIQSerializer
//

@implementation TLListObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLListObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLListObjectIQ *listObjectIQ = (TLListObjectIQ *)object;
    [encoder writeUUID:listObjectIQ.objectSchemaId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLListObjectIQ
//

@implementation TLListObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectSchemaId:(nonnull NSUUID *)objectSchemaId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _objectSchemaId = objectSchemaId;
    }
    return self;
}

@end
