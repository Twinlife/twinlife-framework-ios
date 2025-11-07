/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSessionPingIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Session Ping request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"f2cb4a52-7928-42cb-8439-248388b9a4c7",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SessionPingIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"from", "type":"string"},
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSessionPingIQSerializer
//

@implementation TLSessionPingIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSessionPingIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSessionPingIQ *sessionPingIQ = (TLSessionPingIQ *)object;
    [encoder writeString:sessionPingIQ.from];
    [encoder writeString:sessionPingIQ.to];
    [encoder writeUUID:sessionPingIQ.sessionId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLSessionPingIQ
//

@implementation TLSessionPingIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId from:(nonnull NSString *)from to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _from = from;
        _to = to;
        _sessionId = sessionId;
    }
    return self;
}

@end
