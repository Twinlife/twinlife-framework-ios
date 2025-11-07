/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateDescriptorIQ.h"
#import "TLObjectDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * UpdateDescriptor IQ.
 * <p>
 * Schema version 1
 *  Date: 2025/05/21
 *
 * <pre>
 * {
 *  "schemaId":"346eea33-61e9-460d-bf2c-2d6d487a7bc6",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateDescriptorIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"updatedTimestamp", "type":"long"}
 *     {"name":"expireTimeout", "type":["null", "long"]}
 *     {"name":"copyAllowed", "type":["null", "boolean"]}
 *     {"name":"message", "type":"String"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLUpdateDescriptorIQSerializer
//

@implementation TLUpdateDescriptorIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateDescriptorIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateDescriptorIQ *updateObjectIQ = (TLUpdateDescriptorIQ *)object;
    TLDescriptorId *descriptorId = updateObjectIQ.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeLong:updateObjectIQ.updatedTimestamp];
    if (updateObjectIQ.expiredTimeout == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeLong:updateObjectIQ.expiredTimeout.longLongValue];
    }
    if (updateObjectIQ.flagCopyAllowed == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeBoolean:updateObjectIQ.flagCopyAllowed.boolValue];
    }
    [encoder writeOptionalString:updateObjectIQ.message];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t updatedTimestamp = [decoder readLong];
    
    NSNumber *expiredTimeout;
    if ([decoder readEnum] == 0) {
        expiredTimeout = nil;
    } else {
        expiredTimeout = [NSNumber numberWithLongLong:[decoder readLong]];
    }

    NSNumber *copyAllowed;
    if ([decoder readEnum] == 0) {
        copyAllowed = nil;
    } else {
        copyAllowed = [NSNumber numberWithLongLong:[decoder readLong]];
    }

    NSString *message = [decoder readOptionalString];
    return [[TLUpdateDescriptorIQ alloc] initWithSerializer:self requestId:requestId descriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId] updatedTimestamp:updatedTimestamp message:message copyAllowed:copyAllowed expiredTimeout:expiredTimeout];
}

@end

//
// Implementation: TLUpdateDescriptorIQ
//

@implementation TLUpdateDescriptorIQ

static TLUpdateDescriptorIQSerializer *IQ_UPDATE_DESCRIPTOR_SERIALIZER_1;
static const int IQ_UPDATE_DESCRIPTOR_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_UPDATE_DESCRIPTOR_SERIALIZER_1 = [[TLUpdateDescriptorIQSerializer alloc] initWithSchema:@"346eea33-61e9-460d-bf2c-2d6d487a7bc6" schemaVersion:IQ_UPDATE_DESCRIPTOR_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_UPDATE_DESCRIPTOR_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_UPDATE_DESCRIPTOR_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_UPDATE_DESCRIPTOR_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId updatedTimestamp:(int64_t)updatedTimestamp message:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expiredTimeout:(nullable NSNumber *)expiredTimeout {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _descriptorId = descriptorId;
        _updatedTimestamp = updatedTimestamp;
        _message = message;
        _flagCopyAllowed = copyAllowed;
        _expiredTimeout = expiredTimeout;
    }
    return self;
}

@end
