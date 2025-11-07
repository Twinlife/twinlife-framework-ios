/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnSynchronizeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Synchronize IQ response.
 * <p>
 * Schema version 1
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"380ebc30-1aa9-4e66-bcd8-d0436b5724e8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SynchronizeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"senderTimestamp", "type":"long"},
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnSynchronizeIQSerializer
//

@implementation TLOnSynchronizeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnSynchronizeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnSynchronizeIQ *onSynchronizeIQ = (TLOnSynchronizeIQ *)object;
    [encoder writeInt:onSynchronizeIQ.deviceState];
    [encoder writeLong:onSynchronizeIQ.timestamp];
    [encoder writeLong:onSynchronizeIQ.senderTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    int deviceState = [decoder readInt];
    int64_t timestamp = [decoder readLong];
    int64_t senderTimestamp = [decoder readLong];

    return [[TLOnSynchronizeIQ alloc] initWithSerializer:self requestId:requestId deviceState:deviceState timestamp:timestamp senderTimestamp:senderTimestamp];
}

@end

//
// Implementation: TLOnSynchronizeIQ
//

@implementation TLOnSynchronizeIQ

static TLOnSynchronizeIQSerializer *IQ_ON_SYNCHRONIZE_SERIALIZER_1;
static const int IQ_ON_SYNCHRONIZE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_SYNCHRONIZE_SERIALIZER_1 = [[TLOnSynchronizeIQSerializer alloc] initWithSchema:@"380ebc30-1aa9-4e66-bcd8-d0436b5724e8" schemaVersion:IQ_ON_SYNCHRONIZE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_SYNCHRONIZE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {
    
    return IQ_ON_SYNCHRONIZE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_SYNCHRONIZE_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState timestamp:(int64_t)timestamp senderTimestamp:(int64_t)senderTimestamp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _deviceState = deviceState;
        _timestamp = timestamp;
        _senderTimestamp = senderTimestamp;
    }
    return self;
}

@end
