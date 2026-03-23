/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupServiceImpl.h"
#import "TLTwinlife.h"

@interface TLBackupExecutor : NSObject

- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

- (void)startBackup;

@end
