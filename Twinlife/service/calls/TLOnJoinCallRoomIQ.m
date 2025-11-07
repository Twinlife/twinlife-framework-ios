/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnJoinCallRoomIQ.h"
#import "TLMemberSessionInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Join the call room response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"fd30c970-a16c-4346-936d-d541aa239cb8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnJoinCallRoom",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"memberId", "type":"string"},
 *     {"name":"memberCount", "type":"int"},
 *     [{"name":"peerMemberId", "type":"string"},
 *      {"name":"p2pSessionId", [null, "type":"uuid"]}
 *     ]
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnJoinCallRoomIQSerializer
//

@implementation TLOnJoinCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnJoinCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *memberId = [decoder readString];
    NSArray<TLMemberSessionInfo *> *members = [TLMemberSessionInfo deserializeWithDecoder:decoder];

    return [[TLOnJoinCallRoomIQ alloc] initWithSerializer:self requestId:iq.requestId memberId:memberId members:members];
}

@end

//
// Implementation: TLOnJoinCallRoomIQ
//

@implementation TLOnJoinCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId memberId:(nonnull NSString *)memberId members:(nullable NSArray<TLMemberSessionInfo *> *)members {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _memberId = memberId;
        _members = members;
    }
    return self;
}

@end
