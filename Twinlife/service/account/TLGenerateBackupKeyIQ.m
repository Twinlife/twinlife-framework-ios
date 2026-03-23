/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLGenerateBackupKeyIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Generate backup key Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"3d6cef13-f703-415c-bb5c-38459d8e32e1",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GenerateBackupKeyIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"backupId", "type":"uuid"},
 *     {"name":"derivedUserKey", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLGenerateBackupKeyIQSerializer
//

@implementation TLGenerateBackupKeyIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLGenerateBackupKeyIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
   
    TLGenerateBackupKeyIQ *generateBackupKeyIQ = (TLGenerateBackupKeyIQ *)object;
    
    [encoder writeUUID:generateBackupKeyIQ.backupId];
    [encoder writeData:generateBackupKeyIQ.derivedUserKey];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLGenerateBackupKeyIQ
//

@implementation TLGenerateBackupKeyIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId backupId:(nonnull NSUUID *)backupId derivedUserKey:(nonnull NSData *)derivedUserKey {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _backupId = backupId;
        _derivedUserKey = derivedUserKey;
    }
    return self;
}

@end
