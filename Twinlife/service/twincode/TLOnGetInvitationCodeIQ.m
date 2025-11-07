/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnGetInvitationCodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get invitation code response IQ.
 *
 * <pre>
 * {
 *  "schemaId":"a16cf169-81dd-4a47-8787-5856f409e017",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnGetInvitationCodeIQ",
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
 *     {"name": "signature": [null, "type":"bytes"]},
 *     {"name": "twincodeId", "type":"uuid"},
 *     {"name": "publicKey", [null, "type": "string"]}}
 *   ]
 * }
 * </pre>
 */

//
// Implementation: TLOnGetInvitationCodeIQSerializer
//

@implementation TLOnGetInvitationCodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGetInvitationCodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t modificationDate = [decoder readLong];
    NSArray<TLAttributeNameValue *> *attributes = [self deserializeWithDecoder:decoder];
    NSData *signature = [decoder readOptionalData];
    NSUUID *twincodeId = [decoder readUUID];
    NSString *publicKey = [decoder readOptionalString];
    
    return [[TLOnGetInvitationCodeIQ alloc] initWithSerializer:self iq:iq twincodeId:twincodeId modificationDate:modificationDate attributes:attributes signature:signature publicKey:publicKey];
}

@end

//
// Implementation: TLOnGetInvitationCodeIQ
//

@implementation TLOnGetInvitationCodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeId:(nonnull NSUUID *)twincodeId modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature publicKey:(nullable NSString *)publicKey {
    
    self = [super initWithSerializer:serializer iq:iq modificationDate:modificationDate attributes:attributes signature:signature];

    if (self) {
        _twincodeId = twincodeId;
        _publicKey = publicKey;
    }
    
    return self;
}

@end
