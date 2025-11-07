/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLLeaveCallRoomIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Leave the call room request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"ffc5b5d4-a5e7-471e-aef3-97fadfdbda94",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"LeaveCallRoomIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"callRoomId", "type":"uuid"},
 *     {"name":"memberId", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLLeaveCallRoomIQSerializer
//

@implementation TLLeaveCallRoomIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLLeaveCallRoomIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLLeaveCallRoomIQ *leaveCallRoomIQ = (TLLeaveCallRoomIQ *)object;
    [encoder writeUUID:leaveCallRoomIQ.callRoomId];
    [encoder writeString:leaveCallRoomIQ.memberId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLLeaveCallRoomIQ
//

@implementation TLLeaveCallRoomIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _callRoomId = callRoomId;
        _memberId = memberId;
    }
    return self;
}

@end
