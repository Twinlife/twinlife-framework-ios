/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPutImageIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Image put response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"f48fa894-a200-4aa8-a7d4-22ea21cfd008",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPutImageIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name": "offset", "type":"long"}
 *     {"name":"status", ["incomplete", "complete", "error"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnPutImageIQSerializer
//

@implementation TLOnPutImageIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnPutImageIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t offset = [decoder readLong];
    TLPutImageStatusType status;
    switch ([decoder readEnum]) {
        case 0:
            status = TLPutImageStatusTypeIncomplete;
            break;
        case 1:
            status = TLPutImageStatusTypeComplete;
            break;
        case 2:
            status = TLPutImageStatusTypeError;
            break;
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    return [[TLOnPutImageIQ alloc] initWithSerializer:self iq:iq status:status offset:offset];
}

@end

//
// Implementation: TLOnPutImageIQ
//

@implementation TLOnPutImageIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq status:(TLPutImageStatusType)status offset:(int64_t)offset {

    self = [super initWithSerializer:serializer iq:iq];
    if (self) {
        _status = status;
        _offset = offset;
    }
    return self;
}

@end
