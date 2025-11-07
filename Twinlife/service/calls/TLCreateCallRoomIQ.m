/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateCallRoomIQ.h"
#import "TLMemberSessionInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create call room request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"e53c8953-6345-4e77-bf4b-c1dc227d5d2f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateCallRoomIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"ownerId", "type":"uuid"},
 *     {"name":"memberId", "type":"uuid"},
 *     {"name":"mode", "type":"int"},
 *     {"name":"memberCount", "type":"int"},
 *     [{"name":"peerMemberId", "type":"string"},
 *      {"name":"p2pSessionId", [null, "type":"uuid"]},
 *     ],
 *     {"name":"sfuUri", [null, "type":"string"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLCreateCallRoomIQSerializer
//

@implementation TLCreateCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateCallRoomIQ *createCallRoomIQ = (TLCreateCallRoomIQ *)object;
    [encoder writeUUID:createCallRoomIQ.ownerId];
    [encoder writeUUID:createCallRoomIQ.memberId];
    [encoder writeInt:createCallRoomIQ.mode];
    [TLMemberSessionInfo serializeWithEncoder:encoder members:createCallRoomIQ.members];
    [encoder writeOptionalString:createCallRoomIQ.sfuURI];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateCallRoomIQ
//

@implementation TLCreateCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId ownerId:(nonnull NSUUID *)ownerId memberId:(nonnull NSUUID *)memberId  mode:(int)mode members:(nullable NSArray<TLMemberSessionInfo *> *)members sfuURI:(nullable NSString *)sfuURI {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _ownerId = ownerId;
        _memberId = memberId;
        _mode = mode;
        _members = members;
        _sfuURI = sfuURI;
    }
    return self;
}

@end
