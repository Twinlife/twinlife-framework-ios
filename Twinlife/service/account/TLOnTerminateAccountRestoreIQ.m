/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnTerminateAccountRestoreIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Terminate restore response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"a9945fd0-7f68-42ea-8b41-f6bc4d22cfb4",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnTerminateAccountRestoreIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"errorCode", "type":"enum"},
 *     {"name":"restoreCount", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnTerminateAccountRestoreIQSerializer
//

@implementation TLOnTerminateAccountRestoreIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnTerminateAccountRestoreIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    TLBaseServiceErrorCode errorCode = [TLBaseService toErrorCode:[decoder readEnum]];
    int restoreCount = [decoder readInt];
    
    return [[TLOnTerminateAccountRestoreIQ alloc] initWithSerializer:self iq:iq errorCode:errorCode restoreCount:restoreCount];
}

@end

//
// Implementation: TLOnTerminateAccountRestoreIQ
//

@implementation TLOnTerminateAccountRestoreIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq errorCode:(TLBaseServiceErrorCode)errorCode restoreCount:(int)restoreCount {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _errorCode = errorCode;
        _restoreCount = restoreCount;
    }
    return self;
}

@end
