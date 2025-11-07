/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLMemberNotificationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Member notification IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"f7460e42-387c-41fe-97c3-18a5f2a97052",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"MemberNotificationIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"memberId", "type":"string"},
 *     {"name":"p2pSessionId", [null, "type":"uuid"]},
 *     {"name":"status", "type":["NewMember", "NewMemberNeedSession", "DelMember"]},
 *     {"name":"maxFrameWidth", "type":"int"},
 *     {"name":"maxFrameHeight", "type":"int"},
 *     {"name":"frameRate", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLMemberNotificationIQSerializer
//

@implementation TLMemberNotificationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLMemberNotificationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *callRoomId = [decoder readUUID];
    NSString *memberId = [decoder readString];
    NSUUID *p2pSessionId = [decoder readOptionalUUID];
    TLMemberStatus status;
    switch ([decoder readEnum]) {
        case 0:
            status = TLMemberStatusNew;
            break;
            
        case 1:
            status = TLMemberStatusNewNeedSession;
            break;
            
        case 2:
        default:
            status = TLMemberStatusRemoved;
            break;
    }
    int maxFrameWidth = [decoder readInt];
    int maxFrameHeight = [decoder readInt];
    int maxFrameRate = [decoder readInt];

    return [[TLMemberNotificationIQ alloc] initWithSerializer:self requestId:iq.requestId callRoomId:callRoomId memberId:memberId p2pSessionId:p2pSessionId status:status maxFrameWidth:maxFrameWidth maxFrameHeight:maxFrameHeight maxFrameRate:maxFrameRate];
}

@end

//
// Implementation: TLMemberNotificationIQ
//

@implementation TLMemberNotificationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status maxFrameWidth:(int)maxFrameWidth maxFrameHeight:(int)maxFrameHeight maxFrameRate:(int)maxFrameRate {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _memberId = memberId;
        _p2pSessionId = p2pSessionId;
        _status = status;
        _maxFrameWidth = maxFrameWidth;
        _maxFrameHeight = maxFrameHeight;
        _maxFrameRate = maxFrameRate;
    }
    return self;
}

@end
