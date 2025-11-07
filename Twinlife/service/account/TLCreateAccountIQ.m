/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateAccountIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create account Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"84449ECB-F09F-4C12-A936-038948C2D980",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateAccountIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"applicationId", "type":"uuid"},
 *     {"name":"serviceId", "type":"uuid"},
 *     {"name":"apiKey", "type":"string"},
 *     {"name":"accessToken", "type":"string"},
 *     {"name":"applicationName", "type":"string"},
 *     {"name":"applicationVersion", "type":"string"},
 *     {"name":"twinlifeVersion", "type":"string"},
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"accountPassword", "type":"string"},
 *     {"name":"authToken", [null, "type":"string"}]
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLCreateAccountIQSerializer
//

@implementation TLCreateAccountIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateAccountIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateAccountIQ *createAccountIQ = (TLCreateAccountIQ *)object;
    [encoder writeUUID:createAccountIQ.applicationId];
    [encoder writeUUID:createAccountIQ.serviceId];
    [encoder writeString:createAccountIQ.apiKey];
    [encoder writeString:createAccountIQ.accessToken];
    [encoder writeString:createAccountIQ.applicationName];
    [encoder writeString:createAccountIQ.applicationVersion];
    [encoder writeString:createAccountIQ.twinlifeVersion];
    [encoder writeString:createAccountIQ.accountIdentifier];
    [encoder writeString:createAccountIQ.accountPassword];
    [encoder writeOptionalString:createAccountIQ.authToken];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateAccountIQ
//

@implementation TLCreateAccountIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId apiKey:(nonnull NSString *)apiKey accessToken:(nonnull NSString *)accessToken applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion twinlifeVersion:(nonnull NSString *)twinlifeVersion accountIdentifier:(nonnull NSString *)accountIdentifier accountPassword:(nonnull NSString *)accountPassword  authToken:(nullable NSString *)authToken {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _applicationId = applicationId;
        _serviceId = serviceId;
        _apiKey = apiKey;
        _accessToken = accessToken;
        _applicationName = applicationName;
        _applicationVersion = applicationVersion;
        _twinlifeVersion = twinlifeVersion;
        _accountIdentifier = accountIdentifier;
        _accountPassword = accountPassword;
        _authToken = authToken;
    }
    return self;
}

@end
