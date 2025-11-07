/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPutImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image upload IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"6e0db5e2-318a-4a78-8162-ad88c6ae4b07",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PutImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"imageId", "type":"uuid"},
 *     {"name":"kind", ["normal", "thumbnail", "large"]}
 *     {"name":"totalSize", "type":"long"},
 *     {"name":"offset", "type":"long"},
 *     {"name":"data", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPutImageIQSerializer
//

@implementation TLPutImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPutImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPutImageIQ *putImageIQ = (TLPutImageIQ *)object;
    [encoder writeUUID:putImageIQ.imageId];
    switch (putImageIQ.kind) {
        case TLImageServiceKindNormal:
            [encoder writeEnum:0];
            break;

        case TLImageServiceKindThumbnail:
            [encoder writeEnum:1];
            break;

        case TLImageServiceKindLarge:
            [encoder writeEnum:2];
            break;
    }
    [encoder writeLong:putImageIQ.totalSize];
    [encoder writeLong:putImageIQ.offset];
    [encoder writeData:putImageIQ.imageData];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLPutImageIQ
//

@implementation TLPutImageIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId kind:(TLImageServiceKind)kind offset:(int64_t)offset totalSize:(int64_t)totalSize imageData:(nonnull NSData *)imageData {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _imageId = imageId;
        _kind = kind;
        _offset = offset;
        _totalSize = totalSize;
        _imageData = imageData;
    }
    return self;
}

@end
