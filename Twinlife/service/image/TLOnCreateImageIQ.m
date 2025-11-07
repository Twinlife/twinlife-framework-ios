/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image creation response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"dfb67bd7-2e6a-4fd0-b05d-b34b916ea6cf",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"imageId", "type":"uuid"},
 *     {"name":"chunkSize", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnCreateImageIQSerializer
//

@implementation TLOnCreateImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *imageId = [decoder readUUID];
    int64_t chunkSize = [decoder readLong];

    return [[TLOnCreateImageIQ alloc] initWithSerializer:self iq:iq imageId:imageId chunkSize:chunkSize];
}

@end

//
// Implementation: TLOnCreateImageIQ
//

@implementation TLOnCreateImageIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq imageId:(nonnull NSUUID *)imageId chunkSize:(int64_t)chunkSize {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _imageId = imageId;
        _chunkSize = chunkSize;
    }
    return self;
}

@end
