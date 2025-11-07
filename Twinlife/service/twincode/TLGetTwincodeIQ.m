/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGetTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get twincode IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3a9ca7c4-6153-426d-b716-d81fd625293c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GetTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLGetTwincodeIQSerializer
//

@implementation TLGetTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLGetTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGetTwincodeIQ *getTwincodeIQ = (TLGetTwincodeIQ *)object;
    [encoder writeUUID:getTwincodeIQ.twincodeId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLGetTwincodeIQ
//

@implementation TLGetTwincodeIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeId = twincodeId;
    }
    return self;
}

@end
