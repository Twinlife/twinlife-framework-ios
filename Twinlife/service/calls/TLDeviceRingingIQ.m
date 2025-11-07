/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDeviceRingingIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Device Ringing IQ, sent to the caller to indicate that the peer's device has started ringing.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"acd63138-bec7-402d-86d3-b82707d8b40c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"DeviceRingingIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLDeviceRingingIQSerializer
//

@implementation TLDeviceRingingIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLDeviceRingingIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLDeviceRingingIQ *deviceRingingIQ = (TLDeviceRingingIQ *)object;
    
    [encoder writeString:deviceRingingIQ.to];
    [encoder writeUUID:deviceRingingIQ.sessionId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
   
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSString *to = [decoder readString];
    NSUUID *sessionId = [decoder readUUID];
    
    return [[TLDeviceRingingIQ alloc] initWithSerializer:self requestId:iq.requestId to:to sessionId:sessionId];
}

@end

//
// Implementation: TLDeviceRingingIQ
//

@implementation TLDeviceRingingIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _to = to;
        _sessionId = sessionId;
    }
    return self;
}

@end
