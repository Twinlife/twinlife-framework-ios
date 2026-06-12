/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLBackupHeaderInfo.h"

#define TL_BACKUP_HEADER_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"7fe7023c-f2f3-4148-bf40-43ef04e7a86a"]
#define TL_BACKUP_HEADER_BACKUP_SCHEMA_VERSION 2

#define TL_INCOMPATIBLE_VERSION_EXCEPTION @"TLIncompatibleVersionException"
#define TL_INCOMPATIBLE_APP_EXCEPTION @"TLIncompatibleAppException"

@interface TLBackupHeaderHandler : TLBackupHandler<TLBackupHeaderInfo *>

- (nonnull instancetype)initWithFileSignature:(nonnull NSData *)fileSignature;

- (nonnull instancetype)initWithBackupId:(nonnull NSUUID *)backupId date:(int64_t)date salt:(nonnull NSData *)salt applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion fileSignature:(nonnull NSData *)fileSignature;

- (BOOL)checkSignatureWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder;

@end

