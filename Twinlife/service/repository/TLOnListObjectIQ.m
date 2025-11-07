/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnListObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * List object response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"76b7a7e2-cd6d-40da-b556-bcbf7eb56da4",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnListObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"objectId", "type": "uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnListObjectIQSerializer
//

@implementation TLOnListObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnListObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int count = [decoder readInt];
    NSMutableArray<NSUUID *> *objectIds = [[NSMutableArray alloc] initWithCapacity:count];
    while (count > 0) {
        count--;
        [objectIds addObject:[decoder readUUID]];
    }

    return [[TLOnListObjectIQ alloc] initWithSerializer:self requestId:iq.requestId objectIds:objectIds];
}

@end

//
// Implementation: TLOnListObjectIQ
//

@implementation TLOnListObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectIds:(nonnull NSArray<NSUUID *> *)objectIds {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _objectIds = objectIds;
    }
    return self;
}

@end
