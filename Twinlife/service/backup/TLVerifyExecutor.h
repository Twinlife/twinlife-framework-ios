/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupServiceImpl.h"
#import "TLTwinlife.h"

@class TLTwinlifeContext;

@interface TLVerifyExecutor : NSObject

@property (nonatomic) TLRestoreState restoreState;

/// Full constructor for startVerify
- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password backupFilePath:(nonnull NSString *)backupFilePath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

/// Simplified constructor for verifyHeader
- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife backupFilePath:(nonnull NSString *)backupFilePath;

- (TLBackupServiceErrorCode)verifyHeader;

- (void)startVerify;

@end

