/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInviteCallRoomIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Invite a member in the call room request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"8974ff91-a6c6-42d7-b2a2-fc11041892bd",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"InviteCallRoomIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"twincodeId", "type":"uuid"},
 *     {"name":"p2pSessionId", [null, "type":"uuid"]}
 *     {"name":"mode", "type":"int"},
 *     {"name":"maxMemberCount", "type":"int"},
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLInviteCallRoomIQSerializer
//

@implementation TLInviteCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLInviteCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLInviteCallRoomIQ *inviteCallRoomIQ = (TLInviteCallRoomIQ *)object;
    [encoder writeUUID:inviteCallRoomIQ.callRoomId];
    [encoder writeUUID:inviteCallRoomIQ.twincodeId];
    [encoder writeOptionalUUID:inviteCallRoomIQ.p2pSessionId];
    [encoder writeInt:inviteCallRoomIQ.mode];
    [encoder writeInt:inviteCallRoomIQ.maxMemberCount];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *callRoomId = [decoder readUUID];
    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *sessionId = [decoder readOptionalUUID];
    int mode = [decoder readInt];
    int maxMemberCount = [decoder readInt];

    return [[TLInviteCallRoomIQ alloc] initWithSerializer:self requestId:iq.requestId callRoomId:callRoomId twincodeId:twincodeId p2pSessionId:sessionId mode:mode maxMemberCount:maxMemberCount];
}

@end

//
// Implementation: TLInviteCallRoomIQ
//

@implementation TLInviteCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeId:(nonnull NSUUID *)twincodeId p2pSessionId:(nonnull NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _twincodeId = twincodeId;
        _mode = mode;
        _p2pSessionId = p2pSessionId;
        _maxMemberCount = maxMemberCount;
    }
    return self;
}

@end
