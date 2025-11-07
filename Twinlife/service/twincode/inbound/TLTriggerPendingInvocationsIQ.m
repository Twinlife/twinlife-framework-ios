/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTriggerPendingInvocationsIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Trigger Pending Invocations IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"266f3d93-1782-491c-b6cb-28cc23df4fdf",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TriggerPendingInvocationsIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"filters", [
 *       {"name":"filterName", "type": "string"}
 *    ]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLTriggerPendingInvocationsIQSerializer
//

@implementation TLTriggerPendingInvocationsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLTriggerPendingInvocationsIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTriggerPendingInvocationsIQ *triggerPendingInvocationsIQ = (TLTriggerPendingInvocationsIQ *)object;
    if (!triggerPendingInvocationsIQ.filters) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)triggerPendingInvocationsIQ.filters.count];
        for (NSString *filter in triggerPendingInvocationsIQ.filters) {
            [encoder writeString:filter];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLTriggerPendingInvocationsIQ
//

@implementation TLTriggerPendingInvocationsIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId filters:(nullable NSArray<NSString *> *)filters {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _filters = filters;
    }
    return self;
}

@end
