/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateCallRoomIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create Call Room response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"9e53e24a-acf3-4819-8539-2af37272254f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateCallRoomIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"memberId", "type":"string"},
 *     {"name":"maxMemberCount", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnCreateCallRoomIQSerializer
//

@implementation TLOnCreateCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *callRoomId = [decoder readUUID];
    NSString *memberId = [decoder readString];
    int mode = [decoder readInt];
    int maxMemberCount = [decoder readInt];

    return [[TLOnCreateCallRoomIQ alloc] initWithSerializer:self requestId:iq.requestId callRoomId:callRoomId memberId:memberId mode:mode maxMemberCount:maxMemberCount];
}

@end

//
// Implementation: TLOnCreateCallRoomIQ
//

@implementation TLOnCreateCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _memberId = memberId;
        _mode = mode;
        _maxMemberCount = maxMemberCount;
    }
    return self;
}

@end
