/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLRestoreRequestIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Restore Request after the RestoreChallenge request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"8576bcf4-5901-4e54-b5d5-7e3b70622a7f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"RestoreRequestIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"accountIdentifier", "type":"string"},
 *     {"name":"resourceIdentifier", "type":"string"},
 *     {"name":"deviceNonce", "type":"bytes"},
 *     {"name":"deviceProof", "type":"bytes"},
 *     {"name":"backupId", "type":"uuid"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLRestoreRequestIQSerializer
//

@implementation TLRestoreRequestIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLRestoreRequestIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
   
    TLRestoreRequestIQ *generateBackupKeyIQ = (TLRestoreRequestIQ *)object;

    [encoder writeString:generateBackupKeyIQ.accountIdentifier];
    [encoder writeString:generateBackupKeyIQ.resourceIdentifier];
    [encoder writeData:generateBackupKeyIQ.deviceNonce];
    [encoder writeData:generateBackupKeyIQ.deviceProof];
    [encoder writeUUID:generateBackupKeyIQ.backupId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLRestoreRequestIQ
//

@implementation TLRestoreRequestIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId accountIdentifier:(nonnull NSString *)accountIdentifier resourceIdentifier:(nonnull NSString *)resourceIdentifier deviceNonce:(nonnull NSData *)deviceNonce deviceProof:(nonnull NSData *)deviceProof backupId:(nonnull NSUUID *)backupId {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _accountIdentifier = accountIdentifier;
        _resourceIdentifier = resourceIdentifier;
        _deviceNonce = deviceNonce;
        _deviceProof = deviceProof;
        _backupId = backupId;
    }
    return self;
}

@end
