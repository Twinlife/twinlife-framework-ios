/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Delete twincode IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"cf8f2889-4ee2-4e50-a26a-5cbd475bb07a",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"DeleteTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeId", "type":"uuid"}
 *     {"name":"options", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLDeleteTwincodeIQSerializer
//

@implementation TLDeleteTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLDeleteTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLDeleteTwincodeIQ *deleteTwincodeIQ = (TLDeleteTwincodeIQ *)object;
    [encoder writeUUID:deleteTwincodeIQ.twincodeId];
    [encoder writeInt:deleteTwincodeIQ.deleteOptions];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLDeleteTwincodeIQ
//

@implementation TLDeleteTwincodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId deleteOptions:(int)deleteOptions {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeId = twincodeId;
        _deleteOptions = deleteOptions;
    }
    return self;
}

@end
