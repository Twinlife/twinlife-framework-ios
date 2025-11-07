/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCopyImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
* Image copy response IQ.
*
* Schema version 1
* <pre>
* {
*  "schemaId":"ef7b3c03-33d5-49c2-8644-79ea2688403e",
*  "schemaVersion":"1",
*
*  "type":"record",
*  "name":"OnCopyImageIQ",
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
// Implementation: TLOnCopyImageIQSerializer
//

@implementation TLOnCopyImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCopyImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *imageId = [decoder readUUID];

    return [[TLOnCopyImageIQ alloc] initWithSerializer:self iq:iq imageId:imageId];
}

@end

//
// Implementation: TLOnCopyImageIQ
//

@implementation TLOnCopyImageIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq imageId:(nonnull NSUUID *)imageId {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _imageId = imageId;
    }
    return self;
}

@end
