/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInvocationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Invoke twincode response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"35d11e72-84d7-4a3b-badd-9367ef8c9e43",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"InvocationIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"invocationId", "type":"uuid"}
 *  ]
 * }
 * </pre>
 *
 * Acknowledge invocation IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"eee63e5e-8af1-41e9-9a1b-79806a0056a2",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"InvocationIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"invocationId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLInvocationIQSerializer
//

@implementation TLInvocationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLInvocationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLInvocationIQ *invocationIQ = (TLInvocationIQ *)object;
    [encoder writeUUID:invocationIQ.invocationId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *invocationId = [decoder readUUID];
    return [[TLInvocationIQ alloc] initWithSerializer:self requestId:iq.requestId invocationId:invocationId];
}

@end

//
// Implementation: TLInvocationIQ
//

@implementation TLInvocationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _invocationId = invocationId;
    }
    return self;
}

@end
