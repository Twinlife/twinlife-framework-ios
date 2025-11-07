/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInvokeTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Invoke twincode IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"c74e79e6-5157-4fb4-bad8-2de545711fa0",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"InvokeTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"invocationOptions", "type":"int"},
 *     {"name":"invocationId", [null, "type":"uuid"]},
 *     {"name":"twincodeId", "type":"uuid"},
 *     {"name":"actionName", "type": "string"}
 *     {"name":"attributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]},
 *     {"name": "data": [null, "type":"bytes"]}
 *     {"name": "deadline", "type":"long"}
 *  ]
 * }
 * </pre>
 * Schema version 1 (REMOVED 2024-02-02 after 22.x)
 */

//
// Implementation: TLInvokeTwincodeIQSerializer
//

@implementation TLInvokeTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLInvokeTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLInvokeTwincodeIQ *invokeTwincodeIQ = (TLInvokeTwincodeIQ *)object;
    [encoder writeInt:invokeTwincodeIQ.invocationOptions];
    [encoder writeOptionalUUID:invokeTwincodeIQ.invocationId];
    [encoder writeUUID:invokeTwincodeIQ.twincodeId];
    [encoder writeString:invokeTwincodeIQ.actionName];
    [self serializeWithEncoder:encoder attributes:invokeTwincodeIQ.attributes];
    if (invokeTwincodeIQ.data && invokeTwincodeIQ.dataLength > 0) {
        [encoder writeInt:1];
        [encoder writeDataWithData:invokeTwincodeIQ.data start:0 length:invokeTwincodeIQ.dataLength];
    } else {
        [encoder writeInt:0];
    }
    [encoder writeLong:invokeTwincodeIQ.deadline];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int invocationOptions = [decoder readInt];
    NSUUID *invocationId = [decoder readOptionalUUID];
    NSUUID *twincodeId = [decoder readUUID];
    NSString *actionName = [decoder readString];
    NSMutableArray<TLAttributeNameValue *> *attributes = [self deserializeWithDecoder:decoder];
    NSData *data = [decoder readOptionalData];
    int64_t deadline = [decoder readLong];
    return [[TLInvokeTwincodeIQ alloc] initWithSerializer:self requestId:iq.requestId twincodeId:twincodeId invocationOptions:invocationOptions invocationId:invocationId actionName:actionName attributes:attributes data:data dataLength:(int)data.length deadline:deadline];
}

@end

//
// Implementation: TLInvokeTwincodeIQ
//

@implementation TLInvokeTwincodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId invocationOptions:(int)invocationOptions invocationId:(nullable NSUUID *)invocationId actionName:(nonnull NSString *)actionName attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes data:(nullable NSData *)data dataLength:(int)dataLength deadline:(int64_t)deadline {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeId = twincodeId;
        _invocationOptions = invocationOptions;
        _invocationId = invocationId;
        _actionName = actionName;
        _attributes = attributes;
        _data = data;
        _dataLength = dataLength;
        _deadline = deadline;
    }
    return self;
}

@end
