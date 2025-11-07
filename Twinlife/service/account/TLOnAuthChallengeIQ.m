/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnAuthChallengeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Authenticate Challenge Response IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"A5F47729-2FEE-4B38-AC91-3A67F3F9E1B6",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnAuthChallengeIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"salt", "type":"bytes"},
 *     {"name":"iteration", "type":"int"},
 *     {"name":"server-nonce", "type":"bytes"},
 *     {"name":"serverTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"A5F47729-2FEE-4B38-AC91-3A67F3F9E1B6",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnAuthChallengeIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"salt", "type":"bytes"},
 *     {"name":"iteration", "type":"int"},
 *     {"name":"server-nonce", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnAuthChallengeIQSerializer
//

@implementation TLOnAuthChallengeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnAuthChallengeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSData *salt = [decoder readData];
    int iterations = [decoder readInt];
    NSData *serverNonce = [decoder readData];
    int64_t serverTimestamp = [decoder readLong];

    return [[TLOnAuthChallengeIQ alloc] initWithSerializer:self iq:iq salt:salt iterations:iterations serverNonce:serverNonce serverTimestamp:serverTimestamp];
}

@end

//
// Implementation: TLOnAuthChallengeIQ
//

@implementation TLOnAuthChallengeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq salt:(nonnull NSData *)salt iterations:(int)iterations serverNonce:(nonnull NSData *)serverNonce serverTimestamp:(int64_t)serverTimestamp {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _salt = salt;
        _iterations = iterations;
        _serverNonce = serverNonce;
        _serverTimestamp = serverTimestamp;
    }
    return self;
}

- (nonnull NSString *)serverFirstMessageBare {
    
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];

    [result appendString:[self.salt base64EncodedStringWithOptions:0]];
    [result appendString:[NSString stringWithFormat:@"%i", self.iterations]];
    [result appendString:[[self.serverNonce base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];

    return result;
}

@end
