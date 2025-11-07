/*
 *  Copyright (c) 2021-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateConfigurationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update configuration IQ.
 *
 * Schema version 1 and version 2
 * <pre>
 * {
 *  "schemaId":"3b726b45-c3fc-4062-8ecd-0ddab2dd1537",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateConfigurationIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"environmentId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLUpdateConfigurationIQSerializer
//

@implementation TLUpdateConfigurationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateConfigurationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateConfigurationIQ *updateConfigurationIQ = (TLUpdateConfigurationIQ *)object;
    [encoder writeOptionalUUID:updateConfigurationIQ.environmentId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLUpdateConfigurationIQ
//

@implementation TLUpdateConfigurationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId environmentId:(nullable NSUUID *)environmentId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _environmentId = environmentId;
    }
    return self;
}

@end
