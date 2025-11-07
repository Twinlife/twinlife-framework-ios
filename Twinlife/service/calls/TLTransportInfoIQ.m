/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTransportInfoIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSessionInitiateIQ.h"
#import "TLSdp.h"

#define HAS_NEXT_MARKER 0x10000

/**
 * Transport Info request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"fdf1bba1-0c16-4b12-a59c-0f70cf4da1d9",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TransportInfoIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"},
 *     {"name":"expirationDeadline", "type":"long"},
 *     {"name":"mode", "type":"int"},
 *     {"name":"sdp", "type":"bytes"}
 *     [
 *       {"name":"mode", "type":"int"},
 *       {"name":"sdp", "type":"bytes"}
 *       ...
 *     ]
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLTransportInfoIQSerializer
//

@implementation TLTransportInfoIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLTransportInfoIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTransportInfoIQ *transportInfoIQ = (TLTransportInfoIQ *)object;
    [encoder writeString:transportInfoIQ.to];
    [encoder writeUUID:transportInfoIQ.sessionId];
    [encoder writeLong:transportInfoIQ.expirationDeadline];
    [encoder writeInt:transportInfoIQ.mode];
    [encoder writeData:transportInfoIQ.sdp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSString *to = [decoder readString];
    NSUUID *sessionId = [decoder readUUID];
    int64_t expirationDeadline = [decoder readLong];

    // The server can somehow concatenate several transport-info together.
    // When the transport-info is not encrypted, they are merged and re-compressed within the server.
    // Otherwise, the server cannot decrypt and we append them to the TransportInfoIQ packet with a marker.
    // This marker is cleared by the server in case a client sent it!
    TLTransportInfoIQ *nextTransportInfoIQ = nil;
    int mode;
    NSData *sdp;
    while (YES) {
        mode = [decoder readInt];
        sdp = [decoder readData];
        if ((mode & HAS_NEXT_MARKER) == 0) {
            break;
        }
        mode &= ~HAS_NEXT_MARKER;
        nextTransportInfoIQ = [[TLTransportInfoIQ alloc] initWithSerializer:self requestId:iq.requestId to:to sessionId:sessionId expirationDeadline:expirationDeadline mode:mode sdp:sdp next:nextTransportInfoIQ];
    }

    return [[TLTransportInfoIQ alloc] initWithSerializer:self requestId:iq.requestId to:to sessionId:sessionId expirationDeadline:expirationDeadline mode:mode sdp:sdp next:nextTransportInfoIQ];
}

@end

//
// Implementation: TLTransportInfoIQ
//

@implementation TLTransportInfoIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId expirationDeadline:(int64_t)expirationDeadline mode:(int)mode sdp:(nonnull NSData*)sdp next:(nullable TLTransportInfoIQ *)next {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _to = to;
        _sessionId = sessionId;
        _expirationDeadline = expirationDeadline;
        _mode = mode;
        _sdp = sdp;
        _next = next;
    }
    return self;
}

/// Get the SDP as the Sdp instance.
///
/// @return the sdp instance.
- (nonnull TLSdp *)makeSdp {
    
    BOOL compressed = (self.mode & OFFER_COMPRESSED) != 0;
    int keyIndex = (self.mode & OFFER_ENCRYPT_MASK) >> OFFER_ENCRYPT_SHIFT;
    return [[TLSdp alloc] initWithData:self.sdp compressed:compressed keyIndex:keyIndex];
}

@end
