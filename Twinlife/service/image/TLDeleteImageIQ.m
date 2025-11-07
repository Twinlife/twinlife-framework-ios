/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image delete IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"22a99e04-6485-4808-9f08-4e421e2e5241",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"DeleteImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"imageId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLDeleteImageIQSerializer
//

@implementation TLDeleteImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLDeleteImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLDeleteImageIQ *deleteImageIQ = (TLDeleteImageIQ *)object;
    [encoder writeUUID:deleteImageIQ.imageId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLDeleteImageIQ
//

@implementation TLDeleteImageIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _imageId = imageId;
    }
    return self;
}

@end
