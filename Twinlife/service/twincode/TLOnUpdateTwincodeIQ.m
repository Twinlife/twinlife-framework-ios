/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnUpdateTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update twincode response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"2b0ff6f7-75bb-44a6-9fac-0a9b28fc84dd",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"modificationDate", "type":"long"},
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnUpdateTwincodeIQSerializer
//

@implementation TLOnUpdateTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnUpdateTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t modificationDate = [decoder readLong];
    return [[TLOnUpdateTwincodeIQ alloc] initWithSerializer:self iq:iq modificationDate:modificationDate];
}

@end

//
// Implementation: TLOnUpdateTwincodeIQ
//

@implementation TLOnUpdateTwincodeIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq modificationDate:(int64_t)modificationDate {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _modificationDate = modificationDate;
    }
    return self;
}

@end
