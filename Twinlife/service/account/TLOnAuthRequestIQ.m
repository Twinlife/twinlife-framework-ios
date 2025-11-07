/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnAuthRequestIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Authenticate Request Response IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"9CEE4256-D2B7-4DE3-A724-1F61BB1454C8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnAuthRequestIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"serviceSignature", "type":"bytes"},
 *     {"name":"serverTimestamp", "type":"long"},
 *     {"name":"serverLatency", "type":"int"},
 *     {"name":"deviceTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"9CEE4256-D2B7-4DE3-A724-1F61BB1454C8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnAuthRequestIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"serviceSignature", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnAuthRequestIQSerializer
//

@implementation TLOnAuthRequestIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnAuthRequestIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSData *serverSignature = [decoder readData];
    int64_t serverTimestamp = [decoder readLong];
    int serverLatency = [decoder readInt];
    int64_t deviceTimestamp = [decoder readLong];

    return [[TLOnAuthRequestIQ alloc] initWithSerializer:self iq:iq serverSignature:serverSignature serverLatency:serverLatency serverTimestamp:serverTimestamp deviceTimestamp:deviceTimestamp];
}

@end

//
// Implementation: TLOnAuthRequestIQ
//

@implementation TLOnAuthRequestIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq serverSignature:(nonnull NSData *)serverSignature serverLatency:(int)serverLatency serverTimestamp:(int64_t)serverTimestamp deviceTimestamp:(int64_t)deviceTimestamp {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _serverSignature = serverSignature;
        _serverLatency = serverLatency;
        _serverTimestamp = serverTimestamp;
        _deviceTimestamp = deviceTimestamp;
    }
    return self;
}

@end
