/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupService.h"
#import "TLBackupHeaderInfo.h"

//
// Interface: TLBackupService
//

@interface TLBackupService()

+ (nonnull NSData *)getFileSignature;

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp;

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state;

- (void)onRestoreStateChangeWithState:(TLRestoreState)restoreState restoreContent:(nullable TLRestoreContent *)restoreContent;

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats;

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason;

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report;

@end
