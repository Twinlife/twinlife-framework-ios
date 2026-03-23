/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnGenerateBackupKeyIQ
//

@interface TLOnGenerateBackupKeyIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGenerateBackupKeyIQ
//

@interface TLOnGenerateBackupKeyIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSData *derivedServerKey;
@property (readonly, nullable) NSUUID *lastBackupId;
@property (readonly) int64_t lastBackupTimestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq derivedServerKey:(nonnull NSData *)derivedServerKey lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp;

@end
