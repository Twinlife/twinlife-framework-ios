/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupServiceImpl.h"
#import "TLTwinlife.h"

@class TLTwinlifeContext;

@interface TLRestoreExecutor : NSObject

@property (nonatomic) TLRestoreState restoreState;

- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password backupFilePath:(nonnull NSString *)backupFilePath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds inPlace:(nullable NSNumber *)inPlace twinlifeContext:(nonnull TLTwinlifeContext *)twinlifeContext;

- (void)startRestore;

- (void)commit;

- (void)cancelWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason;

- (void)onTwinlifeOnline;

@end

