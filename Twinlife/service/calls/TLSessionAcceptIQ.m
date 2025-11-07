/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSessionAcceptIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSdp.h"
#import "TLSessionInitiateIQ.h"

/**
 * Session Accept request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"fd545960-d9ac-4e3e-bddf-76f381f163a5",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SessionAcceptIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"from", "type":"string"},
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"},
 *     {"name":"majorVersion", "type":"int"},
 *     {"name":"minorVersion", "type":"int"},
 *     {"name":"offer", "type":"int"},
 *     {"name":"offerToReceive", "type":"int"},
 *     {"name":"priority", "type":"int"},
 *     {"name":"expirationDeadline", "type":"long"},
 *     {"name":"frameSize", "type":"int"},
 *     {"name":"frameRate", "type":"int"},
 *     {"name":"estimatedDataSize", "type":"int"},
 *     {"name":"operationCount", "type":"int"},
 *     {"name":"sdp", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSessionAcceptIQSerializer
//

@implementation TLSessionAcceptIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSessionAcceptIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSessionAcceptIQ *sessionAcceptIQ = (TLSessionAcceptIQ *)object;
    [encoder writeString:sessionAcceptIQ.from];
    [encoder writeString:sessionAcceptIQ.to];
    [encoder writeUUID:sessionAcceptIQ.sessionId];
    [encoder writeInt:sessionAcceptIQ.majorVersion];
    [encoder writeInt:sessionAcceptIQ.minorVersion];
    [encoder writeInt:sessionAcceptIQ.offer];
    [encoder writeInt:sessionAcceptIQ.offerToReceive];
    [encoder writeInt:sessionAcceptIQ.priority];
    [encoder writeLong:sessionAcceptIQ.expirationDeadline];
    [encoder writeInt:sessionAcceptIQ.frameSize];
    [encoder writeInt:sessionAcceptIQ.frameRate];
    [encoder writeInt:sessionAcceptIQ.estimatedDataSize];
    [encoder writeInt:sessionAcceptIQ.operationCount];
    [encoder writeData:sessionAcceptIQ.sdp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *from = [decoder readString];
    NSString *to = [decoder readString];
    NSUUID *sessionId = [decoder readUUID];
    int majorVersion = [decoder readInt];
    int minorVersion = [decoder readInt];
    int offer = [decoder readInt];
    int offerToReceive = [decoder readInt];
    int priority = [decoder readInt];
    int64_t expirationDeadline = [decoder readLong];
    int frameSize = [decoder readInt];
    int frameRate = [decoder readInt];
    int estimatedDataSize = [decoder readInt];
    int operationCount = [decoder readInt];
    NSData *sdp = [decoder readData];

    return [[TLSessionAcceptIQ alloc] initWithSerializer:self requestId:iq.requestId from:from to:to sessionId:sessionId majorVersion:majorVersion minorVersion:minorVersion offer:offer offerToReceive:offerToReceive priority:priority expirationDeadline:expirationDeadline frameSize:frameSize frameRate:frameRate estimatedDataSize:estimatedDataSize operationCount:operationCount sdp:sdp];
}

@end

//
// Implementation: TLSessionAcceptIQ
//

@implementation TLSessionAcceptIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId from:(nonnull NSString *)from to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId majorVersion:(int)majorVersion minorVersion:(int)minorVersion offer:(int)offer offerToReceive:(int)offerToReceive priority:(int)priority expirationDeadline:(int64_t)expirationDeadline frameSize:(int)frameSize frameRate:(int)frameRate estimatedDataSize:(int)estimatedDataSize operationCount:(int)operationCount sdp:(nonnull NSData*)sdp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _from = from;
        _to = to;
        _sessionId = sessionId;
        _offer = offer;
        _offerToReceive = offerToReceive;
        _priority = priority;
        _expirationDeadline = expirationDeadline;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
        _frameSize = frameSize;
        _frameRate = frameRate;
        _estimatedDataSize = estimatedDataSize;
        _operationCount = operationCount;
        _sdp = sdp;
    }
    return self;
}

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp {
    
    BOOL compressed = (self.offer & OFFER_COMPRESSED) != 0;
    int keyIndex = (self.offer & OFFER_ENCRYPT_MASK) >> OFFER_ENCRYPT_SHIFT;
    return [[TLSdp alloc] initWithData:self.sdp compressed:compressed keyIndex:keyIndex];
}

@end
