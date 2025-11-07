/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image creation IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"ea6b4372-3c7d-4ce8-92d8-87a589906a01",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"CreateImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"imageSha", [null, "type":"bytes"]},
 *     {"name":"imageLargeSha", [null, "type":"bytes"]},
 *     {"name":"thumbnail", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLCreateImageIQSerializer
//

@implementation TLCreateImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateImageIQ *createImageIQ = (TLCreateImageIQ *)object;
    [encoder writeData:createImageIQ.thumbnailSha];
    [encoder writeOptionalData:createImageIQ.imageSha];
    [encoder writeOptionalData:createImageIQ.imageLargeSha];
    [encoder writeData:createImageIQ.thumbnail];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateImageIQ
//

@implementation TLCreateImageIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId thumbnailSha:(nullable NSData *)thumbnailSha imageSha:(nullable NSData *)imageSha imageLargeSha:(nullable NSData *)imageLargeSha thumbnail:(nonnull NSData *)thumbnail {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _thumbnailSha = thumbnailSha;
        _imageSha = imageSha;
        _imageLargeSha = imageLargeSha;
        _thumbnail = thumbnail;
    }
    return self;
}

-(long)bufferSize {
    
    long result = [super bufferSize];
    if (self.imageSha) {
        result += self.imageSha.length;
    }
    if (self.imageLargeSha) {
        result += self.imageLargeSha.length;
    }
    if (self.thumbnail) {
        result += self.thumbnail.length;
    }
    return result;
}

@end
