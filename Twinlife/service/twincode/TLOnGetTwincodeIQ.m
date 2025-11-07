/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnGetTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get twincode response IQ.
 * <p>
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"3a9ca7c4-6153-426d-b716-d81fd625293c",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnGetTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"modificationDate", "type":"long"},
 *     {"name":"attributeCount", "type":"int"},
 *     {"name":"attributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]}
 *     {"name": "signature": [null, "type":"bytes"]}
 *   ]
 * }
 * </pre>
 * Schema version 1 (REMOVED 2024-02-02 after 22.x)
 */

//
// Implementation: TLOnGetTwincodeIQSerializer
//

@implementation TLOnGetTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGetTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t modificationDate = [decoder readLong];
    NSArray<TLAttributeNameValue *> *attributes = [self deserializeWithDecoder:decoder];
    NSData *signature = [decoder readOptionalData];
    return [[TLOnGetTwincodeIQ alloc] initWithSerializer:self iq:iq modificationDate:modificationDate attributes:attributes signature:signature];
}

@end

//
// Implementation: TLOnGetTwincodeIQ
//

@implementation TLOnGetTwincodeIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _modificationDate = modificationDate;
        _attributes = attributes;
        _signature = signature;
    }
    return self;
}

@end
