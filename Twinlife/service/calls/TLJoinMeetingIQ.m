/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLJoinMeetingIQ.h"
#import "TLPeerCallService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Join the meeting request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"02166307-8400-4521-bec1-1be77d6233e7",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"JoinMeetingIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"meetingTwincodeId", "type":"uuid"},
 *     {"name":"memberTwincodeId", "type":"uuid"},
 *     {"name":"maxDelay", "type":"int"},
 * }
 * </pre>
 */

//
// Implementation: TLJoinMeetingIQSerializer
//

@implementation TLJoinMeetingIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLJoinMeetingIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLJoinMeetingIQ *joinMeetingIQ = (TLJoinMeetingIQ *)object;
    [encoder writeUUID:joinMeetingIQ.meetingTwincodeId];
    [encoder writeUUID:joinMeetingIQ.memberTwincodeId];
    
    [encoder writeInt:joinMeetingIQ.maxWaitTime];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLJoinMeetingIQ
//

@implementation TLJoinMeetingIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId meetingTwincodeId:(nonnull NSUUID *)meetingTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId maxWaitTime:(int)maxWaitTime {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _meetingTwincodeId = meetingTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _maxWaitTime = maxWaitTime;
    }
    return self;
}

@end
