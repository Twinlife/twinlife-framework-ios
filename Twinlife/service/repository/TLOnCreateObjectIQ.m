/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnCreateObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create object response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"fde9aa2f-c0e3-437a-a1d1-0121e72e43bd",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"objectId", "type": "uuid"}
 *     {"name":"creationDate", "type": "long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnCreateObjectIQSerializer
//

@implementation TLOnCreateObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *objectId = [decoder readUUID];
    int64_t creationDate = [decoder readLong];
    return [[TLOnCreateObjectIQ alloc] initWithSerializer:self requestId:iq.requestId objectId:objectId creationDate:creationDate];
}

@end

//
// Implementation: TLOnCreateObjectIQ
//

@implementation TLOnCreateObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectId:(nonnull NSUUID *)objectId creationDate:(int64_t)creationDate {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _objectId = objectId;
        _creationDate = creationDate;
    }
    return self;
}

@end
