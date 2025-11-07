/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCopyImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image copy IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"6c2a932e-3dc6-47f2-b253-6975818d3a3c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CopyImageIQ",
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
// Implementation: TLCopyImageIQSerializer
//

@implementation TLCopyImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCopyImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCopyImageIQ *copyImageIQ = (TLCopyImageIQ *)object;
    [encoder writeUUID:copyImageIQ.imageId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCopyImageIQ
//

@implementation TLCopyImageIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _imageId = imageId;
    }
    return self;
}

@end
