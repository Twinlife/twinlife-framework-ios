/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLJoinCallRoomIQ.h"
#import "TLPeerCallService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Join the call room request IQ.
 *
 * Schema version 3
 * <pre>
 * {
 *  "schemaId":"f34ce0b8-8b1c-4384-b7a3-19fddcfd2789",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"JoinCallRoomIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"twincodeId", "type":"uuid"},
 *     {"name":"p2pSessionCount", "type":"int"},
 *     {"name":"p2pSessionIds", [
 *         {"name":"sessionId", "type":"uuid"},
 *         {"name":"peerId", "type":["null", "string"]}
 *     ]
 * }
 * </pre>
 */

//
// Implementation: TLJoinCallRoomIQSerializer
//

@implementation TLJoinCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLJoinCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLJoinCallRoomIQ *joinCallRoomIQ = (TLJoinCallRoomIQ *)object;
    [encoder writeUUID:joinCallRoomIQ.callRoomId];
    [encoder writeUUID:joinCallRoomIQ.twincodeId];
    
    [encoder writeInt:(int)joinCallRoomIQ.p2pSessionIds.count];
    
    for (TLPeerSessionInfo *p2pSessionId in joinCallRoomIQ.p2pSessionIds) {
        [encoder writeUUID:p2pSessionId.p2pSessionId];
        [encoder writeOptionalString:p2pSessionId.peerId];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLJoinCallRoomIQ
//

@implementation TLJoinCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeId:(nonnull NSUUID *)twincodeId p2pSessionIds:(nonnull NSArray<TLPeerSessionInfo *> *)p2pSessionIds {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _twincodeId = twincodeId;
        _p2pSessionIds = [[NSArray alloc] initWithArray:p2pSessionIds];
    }
    return self;
}

@end
