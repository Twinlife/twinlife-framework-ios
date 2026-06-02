/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAddRosterMemberIQ.h"
#import "TLMemberInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Add a member to a secure roster request IQ.
 * <p>
 * Schema version 1
 *  Date: 2026/03/26
 * <pre>
 * {
 *  "schemaId":"abf52b69-e9d4-47c1-864c-9f94cbfa5096",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AddSecureRosterMemberIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"SecureRosterIQ"
 *  "fields": [
 *     {"name":"signingKeyId", "type":"uuid"},
 *     {"name":"members", [
 *       {"name":"newMemberTwincodeId", "type":"uuid"},
 *       {"name":"newMemberPermission", "type":"long"},
 *       {"name":"newMemberPublicKey", "type":"bytes"},
 *       {"name":"signature", "type":"bytes"},
 *       {"name":"rosterKeySignature", "type":"bytes"}
 *     ]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLAddRosterMemberIQSerializer
//

@implementation TLAddRosterMemberIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAddRosterMemberIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAddRosterMemberIQ *addRosterMemberIQ = (TLAddRosterMemberIQ *)object;
    [encoder writeUUID:addRosterMemberIQ.signingKeyId];
    [encoder writeInt:(int)addRosterMemberIQ.members.count];
    for (TLMemberInfo *member in addRosterMemberIQ.members) {
        [encoder writeUUID:member.memberTwincodeId];
        [encoder writeLong:member.memberPermission];
        [encoder writeData:member.memberPublicKey];
        [encoder writeData:member.signature];
        if (member.rosterKeySignature == nil) {
            [encoder writeZero];
        } else {
            [encoder writeData:member.rosterKeySignature];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAddRosterMemberIQ
//

@implementation TLAddRosterMemberIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId signingKeyId:(nonnull NSUUID *)signingKeyId members:(nonnull NSArray<TLMemberInfo *> *)members {

    self = [super initWithSerializer:serializer requestId:requestId rosterId:rosterId];
    
    if (self) {
        _signingKeyId = signingKeyId;
        _members = members;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" signingKeyId=%@ members=%lu", self.signingKeyId, (unsigned long)self.members.count];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLAddRosterMemberIQ:"];
    [self appendTo:string];
    return string;
}

@end
