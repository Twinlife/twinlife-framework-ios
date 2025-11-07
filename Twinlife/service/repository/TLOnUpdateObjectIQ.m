/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnUpdateObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update object response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"0890ec66-0560-4b41-8e65-227119d0b008",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"modificationDate", "type": "long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnUpdateObjectIQSerializer
//

@implementation TLOnUpdateObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnUpdateObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t modificationDate = [decoder readLong];

    return [[TLOnUpdateObjectIQ alloc] initWithSerializer:self requestId:iq.requestId modificationDate:modificationDate];
}

@end

//
// Implementation: TLOnUpdateObjectIQ
//

@implementation TLOnUpdateObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId modificationDate:(int64_t)modificationDate {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _modificationDate = modificationDate;
    }
    return self;
}

@end
