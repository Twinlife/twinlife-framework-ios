/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAuthRequestIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Authenticate Request after the AuthChallenge request IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"BF0A6327-FD04-4DFF-998E-72253CFD91E5",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"AuthRequestIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"resourceIdentifier", "type":"string"},
 *     {"name":"deviceNonce", "type":"bytes"},
 *     {"name":"deviceProof", "type":"bytes"},
 *     {"name":"deviceState", "type":"int"}
 *     {"name":"deviceLatency", "type":"int"},
 *     {"name":"deviceTimestamp", "type":"long"},
 *     {"name":"serverTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"BF0A6327-FD04-4DFF-998E-72253CFD91E5",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AuthRequestIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"resourceIdentifier", "type":"string"},
 *     {"name":"deviceNonce", "type":"bytes"},
 *     {"name":"deviceProof", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLAuthRequestIQSerializer
//

@implementation TLAuthRequestIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAuthRequestIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAuthRequestIQ *authRequestIQ = (TLAuthRequestIQ *)object;
    [encoder writeString:authRequestIQ.accountIdentifier];
    [encoder writeString:authRequestIQ.resourceIdentifier];
    [encoder writeData:authRequestIQ.deviceNonce];
    [encoder writeData:authRequestIQ.deviceProof];
    [encoder writeInt:authRequestIQ.deviceState];
    [encoder writeInt:authRequestIQ.deviceLatency];
    [encoder writeLong:authRequestIQ.deviceTimestamp];
    [encoder writeLong:authRequestIQ.serverTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAuthRequestIQ
//

@implementation TLAuthRequestIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  accountIdentifier:(nonnull NSString *)accountIdentifier resourceIdentifier:(nonnull NSString *)resourceIdentifier deviceNonce:(nonnull NSData *)deviceNonce deviceProof:(nonnull NSData *)deviceProof deviceState:(int)deviceState deviceLatency:(int)deviceLatency deviceTimestamp:(int64_t)deviceTimestamp serverTimestamp:(int64_t)serverTimestamp {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _accountIdentifier = accountIdentifier;
        _resourceIdentifier = resourceIdentifier;
        _deviceNonce = deviceNonce;
        _deviceProof = deviceProof;
        _deviceState = deviceState;
        _deviceLatency = deviceLatency;
        _deviceTimestamp = deviceTimestamp;
        _serverTimestamp = serverTimestamp;
    }
    return self;
}

@end
