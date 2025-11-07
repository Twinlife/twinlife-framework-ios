/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLCreateInvitationCodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create invitation code IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"8dcfcba5-b8c0-4375-a501-d24534ed4a3b",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateInvitationCodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *      {"name":"twincodeId", "type":"uuid"},
 *      {"name":"validityPeriod", "type":"int"},
 *      {"name":"publicKey", [null, "type":"string"]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLCreateInvitationCodeIQSerializer
//

@implementation TLCreateInvitationCodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateInvitationCodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateInvitationCodeIQ *createInvitationCodeIQ = (TLCreateInvitationCodeIQ *)object;
    [encoder writeUUID:createInvitationCodeIQ.twincodeId];
    [encoder writeInt:createInvitationCodeIQ.validityPeriod];
    [encoder writeOptionalString:createInvitationCodeIQ.publicKey];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateInvitationCodeIQ
//

@implementation TLCreateInvitationCodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId validityPeriod:(int)validityPeriod publicKey:(nullable NSString *)publicKey {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeId = twincodeId;
        _validityPeriod = validityPeriod;
        _publicKey = publicKey;
    }
    return self;
}

@end
