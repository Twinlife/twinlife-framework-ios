/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGetImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get image IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3a9ca7c4-6153-426d-b716-d81fd625293c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GetImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"imageId", "type":"uuid"},
 *     {"name":"kind", ["normal", "thumbnail", "large"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLGetImageIQSerializer
//

@implementation TLGetImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLGetImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGetImageIQ *getImageIQ = (TLGetImageIQ *)object;
    [encoder writeUUID:getImageIQ.imageId];
    switch (getImageIQ.kind) {
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
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLGetImageIQ
//

@implementation TLGetImageIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId kind:(TLImageServiceKind)kind {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _imageId = imageId;
        _kind = kind;
    }
    return self;
}

@end
