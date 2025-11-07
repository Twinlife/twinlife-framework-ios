/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create twincode response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"6c0442f5-b0bf-4b7e-9ae5-40ad720b1f71",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"factoryTwincodeId", "type":"uuid"}
 *     {"name":"inbountTwincodeId", "type":"uuid"}
 *     {"name":"outboundTwincodeId", "type":"uuid"}
 *     {"name":"switchTwincodeId", "type":"uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnCreateTwincodeIQSerializer
//

@implementation TLOnCreateTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *factoryTwincodeId = [decoder readUUID];
    NSUUID *inboundTwincodeId = [decoder readUUID];
    NSUUID *outboundTwincodeId = [decoder readUUID];
    NSUUID *switchTwincodeId = [decoder readUUID];
    return [[TLOnCreateTwincodeIQ alloc] initWithSerializer:self requestId:iq.requestId factoryTwincodeId:factoryTwincodeId inboundTwincodeId:inboundTwincodeId outboundTwincodeId:outboundTwincodeId switchTwincodeId:switchTwincodeId];
}

@end

//
// Implementation: TLOnCreateTwincodeIQ
//

@implementation TLOnCreateTwincodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId factoryTwincodeId:(nonnull NSUUID *)factoryTwincodeId inboundTwincodeId:(nonnull NSUUID *)inboundTwincodeId outboundTwincodeId:(nonnull NSUUID *)outboundTwincodeId switchTwincodeId:(nonnull NSUUID *)switchTwincodeId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _factoryTwincodeId = factoryTwincodeId;
        _inboundTwincodeId = inboundTwincodeId;
        _outboundTwincodeId = outboundTwincodeId;
        _switchTwincodeId = switchTwincodeId;
    }
    return self;
}

@end
