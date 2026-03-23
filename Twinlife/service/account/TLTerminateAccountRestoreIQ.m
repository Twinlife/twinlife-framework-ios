/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTerminateAccountRestoreIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Terminate Account Restore Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"2810fd0c-3973-41f3-912b-57872d881b2d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TLTerminateAccountRestoreIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"commit", "type":"boolean"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLTerminateAccountRestoreIQSerializer
//

@implementation TLTerminateAccountRestoreIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLTerminateAccountRestoreIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTerminateAccountRestoreIQ *terminateAccountRestoreIQ = (TLTerminateAccountRestoreIQ *)object;
    [encoder writeBoolean:terminateAccountRestoreIQ.commit];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLTerminateAccountRestoreIQ
//

@implementation TLTerminateAccountRestoreIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  commit:(BOOL)commit {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _commit = commit;
    }
    return self;
}

@end
