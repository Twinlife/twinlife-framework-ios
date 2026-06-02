/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteRosterMemberIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Delete a member from a secure roster request IQ.
 *
 * Schema version 1
 *  Date: 2026/03/26
 * <pre>
 * {
 *  "schemaId":"e10bbf8e-cab3-4817-9e22-2a8664135ab8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"DeleteSecureRosterMemberIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"SecureRosterIQ"
 *  "fields": [
 *     {"name":"memberId", "type":"uuid"},
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLDeleteRosterMemberIQSerializer
//

@implementation TLDeleteRosterMemberIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLDeleteRosterMemberIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLDeleteRosterMemberIQ *deleteRosterMemberIQ = (TLDeleteRosterMemberIQ *)object;
    [encoder writeUUID:deleteRosterMemberIQ.memberId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLDeleteRosterMemberIQ
//

@implementation TLDeleteRosterMemberIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId memberId:(nonnull NSUUID *)memberId {

    self = [super initWithSerializer:serializer requestId:requestId rosterId:rosterId];
    
    if (self) {
        _memberId = memberId;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" memberId=%@", self.memberId];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLDeleteRosterMemberIQ:"];
    [self appendTo:string];
    return string;
}

@end
