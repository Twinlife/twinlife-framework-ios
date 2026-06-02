/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnListRosterIQ.h"
#import "TLSecureRosterService.h"
#import "TLCryptoService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * On list secure roster members response IQ.
 *
 * Schema version 1
 *  Date: 2026/03/26
 * <pre>
 * {
 *  "schemaId":"299B036C-2589-4367-8DF3-3F61EF5B2268",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnListSecureRosterIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": {
 *     {"name":"keys", "type":"array", "items": {
 *         "type":"record",
 *         "name":"RosterSignatureKey",
 *         "fields": [
 *             {"name":"keyId", "type":"uuid"},
 *             {"name":"signerKeyId", "type":"uuid"},
 *             {"name":"publicKey", "type":"bytes"},
 *             {"name":"signature", "type":"bytes"},
 *             {"name":"members", "type":"array", "items": {
 *                 "type":"record",
 *                 "name":"RosterMember",
 *                 "fields": [
 *                     {"name":"memberTwincodeId", "type":"uuid"},
 *                     {"name":"creationDate", "type":"long"},
 *                     {"name":"modificationDate", "type":"long"},
 *                     {"name":"permissions", "type":"long"},
 *                     {"name":"publicKey", "type":"bytes"},
 *                     {"name":"signature", "type":"bytes"}
 *                 ]
 *             }}
 *         ]
 *     }}
 *  }
 * }
 * </pre>
 */

//
// Implementation: TLOnListRosterIQSerializer
//

@implementation TLOnListRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnListRosterIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int maxMemberCount = [decoder readInt];
    int keyCount = [decoder readInt];
    NSMutableArray<TLSignedRosterGroup *> *keys = [NSMutableArray arrayWithCapacity:keyCount];
    while (keyCount > 0) {
        keyCount--;
        NSUUID *keyId = [decoder readUUID];
        NSUUID *signerKeyId = [decoder readUUID];
        NSData *publicKey = [decoder readData];
        NSData *signature = [decoder readData];

        int memberCount = [decoder readInt];
        NSMutableArray<TLRosterMember *> *members = [NSMutableArray arrayWithCapacity:memberCount];
        while (memberCount > 0) {
            memberCount--;
            NSUUID *memberTwincodeId = [decoder readUUID];
            int64_t creationDate = [decoder readLong];
            int64_t modificationDate = [decoder readLong];
            int64_t permissions = [decoder readLong];
            NSData *memberPublicKey = [decoder readData];
            NSData *memberSignature = [decoder readData];
            TLRosterMember *member = [[TLRosterMember alloc] initWithMemberTwincodeId:memberTwincodeId
                                                                        creationDate:creationDate
                                                                   modificationDate:modificationDate
                                                                         permissions:permissions
                                                                            publicKey:[[TLPublicKeyData alloc] initWithData:memberPublicKey]
                                                                          signature:memberSignature];
            [members addObject:member];
        }
        TLSignedRosterGroup *group = [[TLSignedRosterGroup alloc] initWithKeyId:keyId
                                                                     signingKeyId:signerKeyId
                                                                      publicKey:[[TLPublicKeyData alloc] initWithData:publicKey]
                                                                       signature:signature
                                                                        members:members];
        [keys addObject:group];
    }

    return [[TLOnListRosterIQ alloc] initWithSerializer:self requestId:iq.requestId maxMemberCount:maxMemberCount keys:keys];
}

@end

//
// Implementation: TLOnListRosterIQ
//

@implementation TLOnListRosterIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId maxMemberCount:(int)maxMemberCount keys:(nonnull NSArray<TLSignedRosterGroup *> *)keys {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _keys = keys;
        _maxMemberCount = maxMemberCount;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" keysCount=%lu", (unsigned long)self.keys.count];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLOnListRosterIQ:"];
    [self appendTo:string];
    return string;
}

@end
