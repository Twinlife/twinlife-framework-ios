/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateAccountIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create Account Response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3D8A1111-61F8-4B27-8229-43DE24A9709B",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateAccountIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"environmentId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnCreateAccountIQSerializer
//

@implementation TLOnCreateAccountIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateAccountIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *environmentId = [decoder readUUID];

    return [[TLOnCreateAccountIQ alloc] initWithSerializer:self iq:iq environmentId:environmentId];
}

@end

//
// Implementation: TLOnCreateAccountIQ
//

@implementation TLOnCreateAccountIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq environmentId:(nonnull NSUUID *)environmentId {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _environmentId = environmentId;
    }
    return self;
}

@end
