/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAuthChallengeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Authenticate Challenge Request IQ.
 *
 * Schema version 1, Schema version 2
 * <pre>
 * {
 *  "schemaId":"91780AB7-016A-463B-9901-434E52C200AE",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AuthChallengeIQ",
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
 *     {"name":"nonce", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLAuthChallengeIQSerializer
//

@implementation TLAuthChallengeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAuthChallengeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAuthChallengeIQ *authChallengeIQ = (TLAuthChallengeIQ *)object;
    [encoder writeUUID:authChallengeIQ.applicationId];
    [encoder writeUUID:authChallengeIQ.serviceId];
    [encoder writeString:authChallengeIQ.apiKey];
    [encoder writeString:authChallengeIQ.accessToken];
    [encoder writeString:authChallengeIQ.applicationName];
    [encoder writeString:authChallengeIQ.applicationVersion];
    [encoder writeString:authChallengeIQ.twinlifeVersion];
    [encoder writeString:authChallengeIQ.accountIdentifier];
    [encoder writeData:authChallengeIQ.nonce];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAuthChallengeIQ
//

@implementation TLAuthChallengeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId apiKey:(nonnull NSString *)apiKey accessToken:(nonnull NSString *)accessToken applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion twinlifeVersion:(nonnull NSString *)twinlifeVersion accountIdentifier:(nonnull NSString *)accountIdentifier nonce:(nonnull NSData *)nonce {

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
        _nonce = nonce;
    }
    return self;
}

- (nonnull NSString *)clientFirstMessageBare {
    
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];

    [result appendString:[[self.applicationId UUIDString] lowercaseString]];
    [result appendString:[[self.serviceId UUIDString] lowercaseString]];
    [result appendString:self.apiKey];
    [result appendString:self.accessToken];
    [result appendString:self.applicationName];
    [result appendString:self.applicationVersion];
    [result appendString:self.twinlifeVersion];
    [result appendString:self.accountIdentifier];
    [result appendString:[[self.nonce base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];

    return result;
}

@end
