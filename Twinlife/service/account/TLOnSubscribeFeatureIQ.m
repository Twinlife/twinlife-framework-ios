/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnSubscribeFeatureIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Subscribe Feature Response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"50FEC907-1D63-4617-A099-D495971930EF",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnSubscribeFeatureIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryErrorPacketIQ"
 *  "fields": [
 *     {"name":"featureList", [null, "type":"String"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnSubscribeFeatureIQSerializer
//

@implementation TLOnSubscribeFeatureIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnSubscribeFeatureIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryErrorPacketIQ *iq = (TLBinaryErrorPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *features = [decoder readOptionalString];

    return [[TLOnSubscribeFeatureIQ alloc] initWithSerializer:self iq:iq features:features];

}

@end

//
// Implementation: TLOnSubscribeFeatureIQ
//

@implementation TLOnSubscribeFeatureIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryErrorPacketIQ *)iq features:(nullable NSString *)features {

    self = [super initWithSerializer:serializer requestId:iq.requestId errorCode:iq.errorCode];
    
    if (self) {
        _features = features;
    }
    return self;
}

@end
