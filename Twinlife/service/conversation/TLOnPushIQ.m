/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * OnPush IQ.
 * <p>
 * Schema version N
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"<XXXXX>",
 *  "schemaVersion":"N",
 *
 *  "type":"record",
 *  "name":"OnPushIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnPushIQSerializer
//

@implementation TLOnPushIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnPushIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnPushIQ *onPushIQ = (TLOnPushIQ *)object;
    [encoder writeInt:onPushIQ.deviceState];
    [encoder writeLong:onPushIQ.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    int deviceState = [decoder readInt];
    int64_t receivedTimestamp = [decoder readLong];

    return [[TLOnPushIQ alloc] initWithSerializer:self requestId:requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLOnPushIQ
//

@implementation TLOnPushIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState receivedTimestamp:(int64_t)receivedTimestamp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _deviceState = deviceState;
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

@end
