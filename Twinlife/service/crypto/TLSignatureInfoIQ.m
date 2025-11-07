/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLSignatureInfoIQ.h"
#import "TLOnPushIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * SignatureInfoIQ IQ.
 * <p>
 * Schema version 1
 * Date: 2024/07/26
 *
 * <pre>
 * {
 *  "schemaId":"e08a0f39-fb5c-4e54-9f4c-eb0fd60b5a37",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SignatureInfoIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"UUID"},
 *     {"name":"publicKey", "type":"String"},
 *     {"name":"keyIndex", "type":"int"}
 *     {"name":"secret", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLSignatureInfoIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLSignatureInfoIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSignatureInfoIQ *iq = (TLSignatureInfoIQ *)object;
    
    [encoder writeUUID:iq.twincodeOutboundId];
    [encoder writeString:iq.publicKey];
    [encoder writeInt:iq.keyIndex];
    [encoder writeData:iq.secret];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *twincodeOutboundId = [decoder readUUID];
    NSString *publicKey = [decoder readString];
    int keyIndex = [decoder readInt];
    NSData *secret = [decoder readData];
    
    return [[TLSignatureInfoIQ alloc] initWithSerializer:self iq:iq twincodeOutboundId:twincodeOutboundId publicKey:publicKey keyIndex:keyIndex secret:secret];
}
@end

@implementation TLSignatureInfoIQ

+ (nonnull NSUUID *)SCHEMA_ID {
    return SIGNATURE_INFO_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    return SIGNATURE_INFO_SCHEMA_VERSION;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER {
    return [[TLSignatureInfoIQSerializer alloc] initWithSchema:SIGNATURE_INFO_SCHEMA_ID.UUIDString schemaVersion:SIGNATURE_INFO_SCHEMA_VERSION];
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secret:(nonnull NSData *)secret {
    self = [super initWithSerializer:serializer iq:iq];

    if (self) {
        _twincodeOutboundId = twincodeOutboundId;
        _publicKey = publicKey;
        _keyIndex = keyIndex;
        _secret = secret;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secret:(nonnull NSData *)secret {
    self = [super initWithSerializer:serializer requestId:requestId];

    if (self) {
        _twincodeOutboundId = twincodeOutboundId;
        _publicKey = publicKey;
        _keyIndex = keyIndex;
        _secret = secret;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" twincodeOutboundId: %@", self.twincodeOutboundId.UUIDString];
    [string appendFormat:@" publicKey: %@", self.publicKey];
    [string appendFormat:@" secret: %@", self.secret];
}


- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLSignatureInfoIQ "];
    [self appendTo:description];
    return description;
}

@end

/**
 * TLOnSignatureInfoIQ IQ.
 *
 * Schema version 1
 *  Date: 2024/10/03
 *
 * <pre>
 * {
 *  "schemaId":"cbe0bd4e-7e19-479e-a64d-b0ae6a792161",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnSignatureInfoIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnSignatureInfoIQ
//

@implementation TLOnSignatureInfoIQ

static TLOnPushIQSerializer *IQ_ON_SIGNATURE_INFO_SERIALIZER_1;
static const int IQ_ON_SIGNATURE_INFO_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_SIGNATURE_INFO_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"cbe0bd4e-7e19-479e-a64d-b0ae6a792161" schemaVersion:IQ_ON_SIGNATURE_INFO_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_SIGNATURE_INFO_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION {

    return IQ_ON_SIGNATURE_INFO_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER {
    
    return IQ_ON_SIGNATURE_INFO_SERIALIZER_1;
}

@end

/**
 * TLAckSignatureInfoIQ IQ.
 *
 * Schema version 1
 *  Date: 2024/10/30
 *
 * <pre>
 * {
 *  "schemaId":"d09fbd4c-cb32-448d-916f-c124e247cd21",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AckSignatureInfoIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLAckSignatureInfoIQ
//

@implementation TLAckSignatureInfoIQ

static TLOnPushIQSerializer *IQ_ACK_SIGNATURE_INFO_SERIALIZER_1;
static const int IQ_ACK_SIGNATURE_INFO_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ACK_SIGNATURE_INFO_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"d09fbd4c-cb32-448d-916f-c124e247cd21" schemaVersion:IQ_ACK_SIGNATURE_INFO_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ACK_SIGNATURE_INFO_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION {

    return IQ_ACK_SIGNATURE_INFO_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER {
    
    return IQ_ACK_SIGNATURE_INFO_SERIALIZER_1;
}

@end
