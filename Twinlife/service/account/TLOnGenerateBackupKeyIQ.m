/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnGenerateBackupKeyIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Generate backup key Response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"e5ac97e6-bf8b-4054-9115-17edaee8de83",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnGenerateBackupKeyIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"derivedServerKey", "type":"bytes"},
 *     {"name":"lastBackupId", "type":[null, "uuid"]},
 *     {"name":"lastBackupTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnGenerateBackupKeyIQSerializer
//

@implementation TLOnGenerateBackupKeyIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGenerateBackupKeyIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSData *serverKey = [decoder readData];
    NSUUID *lastBackupId = [decoder readOptionalUUID];
    int64_t lastBackupTimestamp = [decoder readLong];
    
    return [[TLOnGenerateBackupKeyIQ alloc] initWithSerializer:self iq:iq derivedServerKey:serverKey lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];
}

@end

//
// Implementation: TLOnGenerateBackupKeyIQ
//

@implementation TLOnGenerateBackupKeyIQ



- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq derivedServerKey:(nonnull NSData *)derivedServerKey lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp {
    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _derivedServerKey = derivedServerKey;
        _lastBackupId = lastBackupId;
        _lastBackupTimestamp = lastBackupTimestamp;
    }
    return self;
}

@end
