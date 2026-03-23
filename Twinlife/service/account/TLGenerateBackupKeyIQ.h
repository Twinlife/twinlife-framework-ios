/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLGenerateBackupKeyIQ
//

@interface TLGenerateBackupKeyIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLGenerateBackupKeyIQ
//

@interface TLGenerateBackupKeyIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *backupId;
@property (readonly, nonnull) NSData *derivedUserKey;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId backupId:(nonnull NSUUID *)backupId derivedUserKey:(nonnull NSData *)derivedUserKey;

@end
