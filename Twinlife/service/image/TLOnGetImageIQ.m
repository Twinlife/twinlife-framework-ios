/*
 *  Copyright (c) 2020-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnGetImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
* Image get response IQ.
*
* Schema version 1
* <pre>
* {
*  "schemaId":"9ec1280e-a298-4c8b-b0fd-35383f7b5424",
*  "schemaVersion":"1",
*
*  "type":"record",
*  "name":"OnGetImageIQ",
*  "namespace":"org.twinlife.schemas.image",
*  "super":"org.twinlife.schemas.BinaryPacketIQ"
*  "fields": [
*     {"name":"totalSize", "type":"long"},
*     {"name":"offset", "type":"long"},
*     {"name":"data", "type":"bytes"}
*     {"name": "imageSha": [null, "type":"bytes"]}
*  ]
* }
*
* </pre>
*/

//
// Implementation: TLOnGetImageIQSerializer
//

@implementation TLOnGetImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGetImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t total = [decoder readLong];
    int64_t offset = [decoder readLong];
    NSData *imageData = [decoder readData];
    NSData *sha256 = [decoder readOptionalData];

    return [[TLOnGetImageIQ alloc] initWithSerializer:self iq:iq imageData:imageData offset:offset totalSize:total imageSha:sha256];
}

@end

//
// Implementation: TLOnGetImageIQ
//

@implementation TLOnGetImageIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq imageData:(nonnull NSData *)imageData offset:(int64_t)offset totalSize:(int64_t)totalSize imageSha:(nullable NSData *)imageSha {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _imageData = imageData;
        _offset = offset;
        // _size = size;
        _totalSize = totalSize;
        _imageSha = imageSha;
    }
    return self;
}

@end
