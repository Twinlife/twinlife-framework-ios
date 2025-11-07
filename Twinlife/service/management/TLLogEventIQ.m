/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLLogEventIQ.h"
#import "TLManagementServiceImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Log event request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"a2065d6f-a7aa-43cd-9c0e-030ece70d234",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"LogEventIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"eventCount", "type":"int"},[
 *       {"name":"eventId", "type":"string"},
 *       {"name":"eventTimestamp", "type":"long"},
 *       {"name":"eventAttrCount", "type":"int"},[
 *         {"name":"eventAttrName", "type":"string"},
 *         {"name":"eventAttrValue", "type":"string"}
 *       ]
 *     ]
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLLogEventIQSerializer
//

@implementation TLLogEventIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLLogEventIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];

    TLLogEventIQ *logEventIQ = (TLLogEventIQ *)object;
    [encoder writeInt:(int)logEventIQ.events.count];
    for (TLEvent *event in logEventIQ.events) {
        [encoder writeString:event.eventId];
        [encoder writeLong:event.timestamp];
        if (event.key && event.value) {
            [encoder writeInt:1];
            [encoder writeString:event.key];
            [encoder writeString:event.value];
        } else if (event.attributes) {
            [encoder writeInt:(int)event.attributes.count];
            for (NSString *key in event.attributes) {
                [encoder writeString:key];
                [encoder writeString:event.attributes[key]];
            }
        } else {
            [encoder writeInt:0];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLLogEventIQ
//

@implementation TLLogEventIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId events:(nonnull NSArray<TLEvent *> *)events {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _events = events;
    }
    return self;
}

@end
