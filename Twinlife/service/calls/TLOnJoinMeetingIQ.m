/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnJoinMeetingIQ.h"
#import "TLMemberSessionInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Join meeting response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"64728bdd-d4b7-4042-b90d-d94c6a56fae6",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnJoinMeeting",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"memberId", "type":"string"},
 *     {"name":"memberCount", "type":"int"},
 *     [{"name":"peerMemberId", "type":"string"},
 *      {"name":"p2pSessionId", [null, "type":"uuid"]}
 *     ]
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnJoinMeetingIQSerializer
//

@implementation TLOnJoinMeetingIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnJoinMeetingIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *callRoomId = [decoder readUUID];
    NSString *memberId = [decoder readString];
    NSArray<TLMemberSessionInfo *> *members = [TLMemberSessionInfo deserializeWithDecoder:decoder];

    return [[TLOnJoinMeetingIQ alloc] initWithSerializer:self requestId:iq.requestId callRoomId:callRoomId memberId:memberId members:members];
}

@end

//
// Implementation: TLOnJoinMeetingIQ
//

@implementation TLOnJoinMeetingIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nullable NSArray<TLMemberSessionInfo *> *)members {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _memberId = memberId;
        _members = members;
    }
    return self;
}

@end
