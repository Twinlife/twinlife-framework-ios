/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteAccountIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Delete account Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"60e72a89-c1ef-49fa-86a8-0793e5e662e4",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"DeleteAccountIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"accountPassword", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLDeleteAccountIQSerializer
//

@implementation TLDeleteAccountIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLDeleteAccountIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLDeleteAccountIQ *createAccountIQ = (TLDeleteAccountIQ *)object;
    [encoder writeString:createAccountIQ.accountIdentifier];
    [encoder writeString:createAccountIQ.accountPassword];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLDeleteAccountIQ
//

@implementation TLDeleteAccountIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  accountIdentifier:(nonnull NSString *)accountIdentifier accountPassword:(nonnull NSString *)accountPassword {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _accountIdentifier = accountIdentifier;
        _accountPassword = accountPassword;
    }
    return self;
}

@end
