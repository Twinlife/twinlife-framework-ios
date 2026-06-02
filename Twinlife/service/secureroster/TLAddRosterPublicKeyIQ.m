/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAddRosterPublicKeyIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Add a public key to a secure roster request IQ.
 *
 * Schema version 1
 *  Date: 2026/03/26
 * <pre>
 * {
 *  "schemaId":"a0c5183a-062e-412d-b31b-1a6c79b4c6f6",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AddSecureRosterPublicKeyIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"SecureRosterIQ"
 *  "fields": [
 *     {"name":"signingKeyId", "type":"uuid"},
 *     {"name":"newKeyId", "type":"uuid"},
 *     {"name":"newPublicKey", "type":"bytes"}
 *     {"name":"signature", "type":"bytes"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLAddRosterPublicKeyIQSerializer
//

@implementation TLAddRosterPublicKeyIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAddRosterPublicKeyIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAddRosterPublicKeyIQ *addRosterPublicKeyIQ = (TLAddRosterPublicKeyIQ *)object;
    [encoder writeUUID:addRosterPublicKeyIQ.signingKeyId];
    [encoder writeUUID:addRosterPublicKeyIQ.keyId];
    [encoder writeData:addRosterPublicKeyIQ.publicKey];
    [encoder writeData:addRosterPublicKeyIQ.signature];
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAddRosterPublicKeyIQ
//

@implementation TLAddRosterPublicKeyIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId signingKeyId:(nonnull NSUUID *)signingKeyId newKeyId:(nonnull NSUUID *)newKeyId newPublicKey:(nonnull NSData *)newPublicKey signature:(nonnull NSData *)signature {

    self = [super initWithSerializer:serializer requestId:requestId rosterId:rosterId];
    
    if (self) {
        _signingKeyId = signingKeyId;
        _keyId = newKeyId;
        _publicKey = newPublicKey;
        _signature = signature;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" rosterId=%@ newKeyId=%@", self.rosterId, self.keyId];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLAddRosterPublicKeyIQ:"];
    [self appendTo:string];
    return string;
}

@end
