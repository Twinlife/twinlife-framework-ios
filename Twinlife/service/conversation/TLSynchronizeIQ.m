/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSynchronizeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Synchronize IQ.
 * <p>
 * Schema version 1
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"d2447a5f-7aed-439a-808b-2858c5f1ba39",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SynchronizeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"UUID"},
 *     {"name":"resourceId", "type":"UUID"},
 *     {"name":"timestamp", "type":"long"},
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSynchronizeIQSerializer
//

@implementation TLSynchronizeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSynchronizeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSynchronizeIQ *synchronizeIQ = (TLSynchronizeIQ *)object;
    [encoder writeUUID:synchronizeIQ.twincodeOutboundId];
    [encoder writeUUID:synchronizeIQ.resourceId];
    [encoder writeLong:synchronizeIQ.timestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    NSUUID *resourceId = [decoder readUUID];
    int64_t timestamp = [decoder readLong];

    return [[TLSynchronizeIQ alloc] initWithSerializer:self requestId:requestId twincodeOutboundId:twincodeOutboundId resourceId:resourceId timestamp:timestamp];
}

@end

//
// Implementation: TLSynchronizeIQ
//

@implementation TLSynchronizeIQ

static TLSynchronizeIQSerializer *IQ_SYNCHRONIZE_SERIALIZER_1;
static const int IQ_SYNCHRONIZE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_SYNCHRONIZE_SERIALIZER_1 = [[TLSynchronizeIQSerializer alloc] initWithSchema:@"d2447a5f-7aed-439a-808b-2858c5f1ba39" schemaVersion:IQ_SYNCHRONIZE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_SYNCHRONIZE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {
    
    return IQ_SYNCHRONIZE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_SYNCHRONIZE_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId resourceId:(nonnull NSUUID *)resourceId timestamp:(int64_t)timestamp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeOutboundId = twincodeOutboundId;
        _resourceId = resourceId;
        _timestamp = timestamp;
    }
    return self;
}

@end
