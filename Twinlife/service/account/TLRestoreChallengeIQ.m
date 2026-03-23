/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLRestoreChallengeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Restore challenge IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"093b4e5c-3040-48d1-9981-cb1f20c16d89",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StartRestoreChallengeIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"backupId", "type":"uuid"},
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"nonce", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLRestoreChallengeIQSerializer
//

@implementation TLRestoreChallengeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLRestoreChallengeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
   
    TLRestoreChallengeIQ *iq = (TLRestoreChallengeIQ *)object;
    
    [encoder writeUUID:iq.backupId];
    [encoder writeString:iq.accountIdentifier];
    [encoder writeData:iq.nonce];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLRestoreChallengeIQ
//

@implementation TLRestoreChallengeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId backupId:(nonnull NSUUID *)backupId accountIdentifier:(nonnull NSString *)accountIdentifier nonce:(nonnull NSData *)nonce {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _backupId = backupId;
        _accountIdentifier = accountIdentifier;
        _nonce = nonce;
    }
    return self;
}

- (nonnull NSString *)clientFirstMessageBare {
    
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];

    [result appendString:self.backupId.UUIDString.lowercaseString];
    [result appendString:self.accountIdentifier];
    [result appendString:[[self.nonce base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];

    return result;
}


@end
