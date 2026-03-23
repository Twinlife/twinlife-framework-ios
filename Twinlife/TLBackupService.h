/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBaseService.h"
#import "TLBackupHeaderInfo.h"

@class TLBackupInfo;
@class TLRestoreContent;
@class TLTwinlifeContext;
@class TLVerifyReport;

typedef enum {
    TLBackupStateStarting,
    TLBackupStateGenerateKey,
    TLBackupStateCreateFile,
    TLBackupStateTerminated,
} TLBackupState;

typedef enum {
    TLRestoreStateStarting,
    TLRestoreStateRestoreAccount,
    TLRestoreStatePrepareDatabase,
    TLRestoreStateRestoreData,
    TLRestoreStateWaitConfirm,
    TLRestoreStateCommit,
    TLRestoreStateTerminated,
    TLRestoreStateCancel,
    TLRestoreStateSyncingObjects
} TLRestoreState;

typedef enum {
    TLBackupServiceErrorCodeInternalError,
    TLBackupServiceErrorCodeNoSpaceLeft,
    TLBackupServiceErrorCodeIOError,
    TLBackupServiceErrorCodeRevoked,
    TLBackupServiceErrorCodeBadVersion,
    TLBackupServiceErrorCodeKeyGenFailed,
    TLBackupServiceErrorCodeInvalidKey,
    TLBackupServiceErrorCodeInvalidFile,
    TLBackupServiceErrorCodeSyncFailed,
    TLBackupServiceErrorCodeDifferentAccount,
    TLBackupServiceErrorCodeSuccess
} TLBackupServiceErrorCode;


typedef enum {
    TLBackupServiceTerminateReasonSuccess,
    TLBackupServiceTerminateReasonError,
    TLBackupServiceTerminateReasonCancel
} TLBackupServiceTerminateReason;

//
// Interface: TLBackupServiceConfiguration
//

@interface TLBackupServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Protocol: TLBackupServiceDelegate
//

@protocol TLBackupServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp;

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state;

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreContent:(nullable TLRestoreContent *)restoreContent;

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats done:(BOOL)done;

- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason;

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode  baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode  baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode;

- (void)onGetAllBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode backups:(nonnull NSArray<TLBackupInfo *> *)backups;

- (void)onDeleteBackupsWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report;
@end

@interface TLBackupService : TLBaseService

+ (nonnull NSString *)VERSION;

- (void)backupWithPassword:(nonnull NSData *)password supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

- (void)restoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds inPlace:(nullable NSNumber *)inPlace twinlifeContext:(nonnull TLTwinlifeContext *)twinlifeContext;

- (void)verifyWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

- (void)commitRestore;

- (void)cancelRestore;

- (BOOL)isRestoreInProgress;

- (void)getAllBackups;

- (void)deleteBackups;

- (BOOL)checkFileSignatureWithBackupPath:(nonnull NSString *)backupPath;
@end
