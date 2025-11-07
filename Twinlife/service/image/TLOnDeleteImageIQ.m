/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnDeleteImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
* Image delete response IQ.
*
* Schema version 1
* <pre>
* {
*  "schemaId":"9e2f9bb9-b614-4674-b3a6-0474aefa961f",
*  "schemaVersion":"1",
*
*  "type":"record",
*  "name":"OnDeleteImageIQ",
*  "namespace":"org.twinlife.schemas.image",
*  "super":"org.twinlife.schemas.BinaryPacketIQ"
*  "fields": [
*  ]
* }
*
* </pre>
*/

//
// Implementation: TLOnDeleteImageIQSerializer
//

@implementation TLOnDeleteImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnDeleteImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    return [[TLOnDeleteImageIQ alloc] initWithSerializer:self iq:iq];
}

@end

//
// Implementation: TLOnDeleteImageIQ
//

@implementation TLOnDeleteImageIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq {

    return [super initWithSerializer:serializer iq:iq];
}

@end
