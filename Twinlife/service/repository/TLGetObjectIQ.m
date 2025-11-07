/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGetObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get object IQ or Delete object IQ
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"6dc2169c-1ec8-4c4a-9842-ab26b8484813",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GetObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"objectSchemaId", "type": "uuid"}
 *     {"name":"objectId", "type": "uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLGetObjectIQSerializer
//

@implementation TLGetObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLGetObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGetObjectIQ *getObjectIQ = (TLGetObjectIQ *)object;
    [encoder writeUUID:getObjectIQ.objectSchemaId];
    [encoder writeUUID:getObjectIQ.objectId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLGetObjectIQ
//

@implementation TLGetObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectSchemaId:(nonnull NSUUID *)objectSchemaId objectId:(nonnull NSUUID *)objectId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _objectSchemaId = objectSchemaId;
        _objectId = objectId;
    }
    return self;
}

@end
