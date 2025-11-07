/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSessionUpdateIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSdp.h"
#import "TLSessionInitiateIQ.h"

/**
 * Session Update request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"44f0c7d0-8d03-453d-8587-714ef92087ae",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SessionUpdateIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"},
 *     {"name":"expirationDeadline", "type":"long"},
 *     {"name":"update", "type":"int"},
 *     {"name":"sdp", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSessionUpdateIQSerializer
//

@implementation TLSessionUpdateIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSessionUpdateIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSessionUpdateIQ *sessionUpdateIQ = (TLSessionUpdateIQ *)object;
    [encoder writeString:sessionUpdateIQ.to];
    [encoder writeUUID:sessionUpdateIQ.sessionId];
    [encoder writeLong:sessionUpdateIQ.expirationDeadline];
    [encoder writeInt:sessionUpdateIQ.updateType];
    [encoder writeData:sessionUpdateIQ.sdp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *to = [decoder readString];
    NSUUID *sessionId = [decoder readUUID];
    int64_t expirationDeadline = [decoder readLong];
    int updateType = [decoder readInt];
    NSData *sdp = [decoder readData];

    return [[TLSessionUpdateIQ alloc] initWithSerializer:self requestId:iq.requestId to:to sessionId:sessionId expirationDeadline:expirationDeadline updateType:updateType sdp:sdp];
}

@end

//
// Implementation: TLSessionUpdateIQ
//

@implementation TLSessionUpdateIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId expirationDeadline:(int64_t)expirationDeadline updateType:(int)updateType sdp:(nonnull NSData*)sdp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _to = to;
        _sessionId = sessionId;
        _expirationDeadline = expirationDeadline;
        _updateType = updateType;
        _sdp = sdp;
    }
    return self;
}

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp {
    
    BOOL compressed = (self.updateType & OFFER_COMPRESSED) != 0;
    int keyIndex = (self.updateType & OFFER_ENCRYPT_MASK) >> OFFER_ENCRYPT_SHIFT;
    return [[TLSdp alloc] initWithData:self.sdp compressed:compressed keyIndex:keyIndex];
}

@end
