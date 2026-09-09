/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateRosterMemberIQ.h"
#import "TLMemberInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update the member's permission in a secure roster request IQ.
 * <p>
 * Schema version 1
 *  Date: 2026/08/10
 * <pre>
 * {
 *  "schemaId":"9d8dc720-be8e-4fb7-a5f1-4b1ecd0f539f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateRosterMemberIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"SecureRosterIQ"
 *  "fields": [
 *     {"name":"signingKeyId", "type":"uuid"},
 *     {"name":"members", [
 *       {"name":"memberTwincodeId", "type":"uuid"},
 *       {"name":"memberPermission", "type":"long"},
 *       {"name":"signature", "type":"bytes"},
 *       {"name":"rosterKeySignature", "type":"bytes"}
 *     ]}
 *  ]
 * }
 * </pre>
 */


//
// Implementation: TLUpdateRosterMemberIQSerializer
//

@implementation TLUpdateRosterMemberIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateRosterMemberIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateRosterMemberIQ *updateRosterMemberIQ = (TLUpdateRosterMemberIQ *)object;
    [encoder writeUUID:updateRosterMemberIQ.signingKeyId];
    [encoder writeInt:(int)updateRosterMemberIQ.members.count];
    for (TLMemberInfo *member in updateRosterMemberIQ.members) {
        [encoder writeUUID:member.memberTwincodeId];
        [encoder writeLong:member.memberPermission];
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
// Implementation: TLUpdateRosterMemberIQ
//

@implementation TLUpdateRosterMemberIQ

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
    [string appendString:@"TLUpdateRosterMemberIQ:"];
    [self appendTo:string];
    return string;
}

@end
