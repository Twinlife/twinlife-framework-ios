/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAcknowledgeInvocationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Acknowledge invocation IQ.
 * <p>
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"eee63e5e-8af1-41e9-9a1b-79806a0056a2",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"AcknowledgeInvocationIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"invocationId", "type":"uuid"}
 *     {"name":"errorCode", "type":"enum"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLAcknowledgeInvocationIQSerializer
//

@implementation TLAcknowledgeInvocationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAcknowledgeInvocationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAcknowledgeInvocationIQ *invocationIQ = (TLAcknowledgeInvocationIQ *)object;
    [encoder writeUUID:invocationIQ.invocationId];
    [self serializeWithEncoder:encoder errorCode:invocationIQ.errorCode];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAcknowledgeInvocationIQ
//

@implementation TLAcknowledgeInvocationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _invocationId = invocationId;
        _errorCode = errorCode;
    }
    return self;
}

@end
