/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateRosterIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * On create a secure roster response IQ.
 *
 * Schema version 1
 *  Date: 2026/03/25
 * <pre>
 * {
 *  "schemaId":"796995be-2ec5-44c4-b016-7a277e3e9bd3",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateSecureRosterIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"rosterId", "type":"uuid"},
 *     {"name":"maxMemberCount", "type":"int"},
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnCreateRosterIQSerializer
//

@implementation TLOnCreateRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateRosterIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *rosterId = [decoder readUUID];
    int maxMemberCount = [decoder readInt];

    return [[TLOnCreateRosterIQ alloc] initWithSerializer:self requestId:iq.requestId rosterId:rosterId maxMemberCount:maxMemberCount];
}

@end

//
// Implementation: TLOnCreateRosterIQ
//

@implementation TLOnCreateRosterIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId maxMemberCount:(int)maxMemberCount {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _rosterId = rosterId;
        _maxMemberCount = maxMemberCount;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" rosterId=%@ maxMemberCount=%d", self.rosterId, self.maxMemberCount];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLOnCreateRosterIQ:"];
    [self appendTo:string];
    return string;
}

@end
