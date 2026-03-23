/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "TLBackupServiceImpl.h"
#import "TLBaseServiceImpl.h"
#import "TLAccountServiceImpl.h"
#import "TLBackupExecutor.h"
#import "TLRestoreExecutor.h"
#import "TLVerifyExecutor.h"
#import "TLBackupInfo.h"
#import "TLRestoreContent.h"
#import "TLBackupHeaderHandler.h"
#import "TLBinaryDecoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define BACKUP_SERVICE_VERSION @"1.0.0"

#if defined(TWINME) || defined(MYTWINLIFE)
/**
 * Magic bytes identifying a twinme free backup file ("TFBK")
 */
static const uint8_t FILE_SIGNATURE[] = {0x54, 0x46, 0x42, 0x4b};
#endif

#if defined(TWINME_PLUS) || defined(MYTWINLIFE_PLUS)
/**
 * Magic bytes identifying a twinme+ backup file ("TPBK")
 */
static const uint8_t FILE_SIGNATURE[] = {0x54, 0x50, 0x42, 0x4b};
#endif

#ifdef SKRED
/**
 * Magic bytes identifying a skred backup file ("SFBK")
 */
static const uint8_t FILE_SIGNATURE[] = {0x53, 0x46, 0x42, 0x4b};
#endif

//
// Implementation: TLAccountMigrationServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLBackupServiceConfiguration"

@implementation TLBackupServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdManagementService version:TLBackupService.VERSION serviceOn:NO];
    
    return self;
}


@end



#undef LOG_TAG
#define LOG_TAG @"TLBackupService"

@interface TLBackupService ()

@property (nonatomic, nullable) TLBackupExecutor *backupExecutor;
@property (nonatomic, nullable) TLRestoreExecutor *restoreExecutor;
@property (nonatomic, nullable) TLVerifyExecutor *verifyExecutor;

@end

@implementation TLBackupService

+ (nonnull NSString *)VERSION {
    return BACKUP_SERVICE_VERSION;
}

+ (nonnull NSData *)getFileSignature {
    return [NSData dataWithBytes:FILE_SIGNATURE length:sizeof(FILE_SIGNATURE)];
}

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLBackupServiceConfiguration *backupServiceConfiguration = [[TLBackupServiceConfiguration alloc] init];
    
    TLBackupServiceConfiguration *serviceConfiguration = (TLBackupServiceConfiguration *)baseServiceConfiguration;
    
    backupServiceConfiguration.serviceOn = serviceConfiguration.serviceOn;
    self.serviceConfiguration = backupServiceConfiguration;
    self.serviceOn = backupServiceConfiguration.serviceOn;
    self.configured = YES;
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restoreExecutor) {
        [self.restoreExecutor onTwinlifeOnline];
    }
}

- (void)backupWithPassword:(nonnull NSData *)password supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds {
    DDLogVerbose(@"%@ backupWithPassword: %@", LOG_TAG, password);
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured", LOG_TAG);
        return;
    }
    
    self.backupExecutor = [[TLBackupExecutor alloc] initWithBackupService:self twinlife:self.twinlife password:password supportedSchemaIds:supportedSchemaIds];
    
    [self.backupExecutor startBackup];
}

- (void)restoreWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds inPlace:(nullable NSNumber *)inPlace twinlifeContext:(nonnull TLTwinlifeContext *)twinlifeContext {
    DDLogVerbose(@"%@ restoreWithPassword: %@ backupPath: %@", LOG_TAG, password, backupPath);
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured", LOG_TAG);
        return;
    }
    
    self.restoreExecutor = [[TLRestoreExecutor alloc] initWithBackupService:self twinlife:self.twinlife password:password backupFilePath:backupPath supportedSchemaIds:supportedSchemaIds inPlace:inPlace twinlifeContext:twinlifeContext];
    
    [self.restoreExecutor startRestore];
}

- (void)verifyWithPassword:(nonnull NSData *)password backupPath:(nonnull NSString *)backupPath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds {
    DDLogVerbose(@"%@ verifyWithPassword: %@ backupPath: %@", LOG_TAG, password, backupPath);
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured", LOG_TAG);
        return;
    }

    self.verifyExecutor = [[TLVerifyExecutor alloc] initWithBackupService:self twinlife:self.twinlife password:password backupFilePath:backupPath supportedSchemaIds:supportedSchemaIds];
        
    [self.verifyExecutor startVerify];
}

- (void)commitRestore {
    DDLogVerbose(@"%@ commitRestore", LOG_TAG);

    if (!self.restoreExecutor) {
        DDLogError(@"%@ No current restore, can't commit", LOG_TAG);
        return;
    }
    
    
    [self.restoreExecutor commit];
}

- (void)cancelRestore {
    DDLogVerbose(@"%@ cancelRestore", LOG_TAG);

    if (!self.restoreExecutor) {
        DDLogError(@"%@ No current restore, can't rollback", LOG_TAG);
        return;
    }
    
    [self.restoreExecutor cancelWithTerminateReason:TLBackupServiceTerminateReasonCancel];
}

- (BOOL)isRestoreInProgress {
    DDLogVerbose(@"%@ isRestoreInProgress", LOG_TAG);
    
    return self.restoreExecutor != nil && self.restoreExecutor.restoreState != TLRestoreStateTerminated;
}

- (void)getAllBackups {
    DDLogVerbose(@"%@ getAllBackups", LOG_TAG);
    
    [self.twinlife.accountService getAllBackupsWithBlock:^(TLBaseServiceErrorCode status, NSArray<TLBackupInfo *> * _Nullable backups) {
        if (status != TLBaseServiceErrorCodeSuccess || !backups) {
            DDLogError(@"%@ Could not get all backups: %d", LOG_TAG, status);
            backups = [NSArray array];
        }
        
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onGetAllBackupsWithErrorCode:backups:)]) {
                id<TLBackupServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onGetAllBackupsWithErrorCode:status backups:backups];
                });
            }
        }
    }];
}

- (void)deleteBackups {
    DDLogVerbose(@"%@ deleteBackups", LOG_TAG);
    
    [self.twinlife.accountService deleteBackupsWithBlock:^(TLBaseServiceErrorCode status) {
        if (status != TLBaseServiceErrorCodeSuccess) {
            DDLogError(@"%@ Could not delete backups: %d", LOG_TAG, status);
        }
        
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onDeleteBackupsWithErrorCode:)]) {
                id<TLBackupServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onDeleteBackupsWithErrorCode:status];
                });
            }
        }
    }];
}

- (BOOL)checkFileSignatureWithBackupPath:(nonnull NSString *)backupPath {
    DDLogVerbose(@"%@ checkFileSignatureWithBackupPath:%@", LOG_TAG, backupPath);
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:backupPath];
    // Only read a small chunk of data to decode the file signature.
    NSData *signatureData = [fileHandle readDataOfLength:(16)];
    [fileHandle closeFile];

    TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:signatureData];
    TLBackupHeaderHandler *handler = [[TLBackupHeaderHandler alloc] initWithFileSignature:[TLBackupService getFileSignature]];
    
    @try {
        return [handler checkSignatureWithBinaryDecoder:decoder];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Error occurred while reading signature in backup file %@: %@", LOG_TAG, backupPath, exception.userInfo);
        return NO;
    }
}

- (void)onBackupStateChangeWithBackupId:(nonnull NSUUID *)backupId state:(TLBackupState)state {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onBackupStateChangeWithBackupId:state:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onBackupStateChangeWithBackupId:backupId state:state];
            });
        }
    }
}

- (void)onBackupHeaderInfoWithHeaderInfo:(nonnull TLBackupHeaderInfo *)headerInfo lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onBackupHeaderInfoWithHeaderInfo:lastBackupId:lastBackupTimestamp:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onBackupHeaderInfoWithHeaderInfo:headerInfo lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];
            });
        }
    }
}

- (void)onBackupErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onBackupErrorWithBackupErrorCode:baseErrorCode:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onBackupErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
            });
        }
    }
}

- (void)onTerminateBackupWithBackupId:(nonnull NSUUID *)backupId backupFilePath:(nullable NSString *)backupFilePath stats:(nonnull NSDictionary<NSUUID *, NSNumber *> *)stats {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTerminateBackupWithBackupId:backupFilePath:stats:done:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTerminateBackupWithBackupId:backupId backupFilePath:backupFilePath stats:stats done:YES];
            });
        }
    }
}


- (void)onRestoreErrorWithBackupErrorCode:(TLBackupServiceErrorCode)backupErrorCode baseErrorCode:(TLBaseServiceErrorCode)baseErrorCode {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onRestoreErrorWithBackupErrorCode:baseErrorCode:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onRestoreErrorWithBackupErrorCode:backupErrorCode baseErrorCode:baseErrorCode];
            });
        }
    }
}

- (void)onRestoreStateChangeWithState:(TLRestoreState)state restoreContent:(nullable TLRestoreContent *)restoreContent{
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onRestoreStateChangeWithState:restoreContent:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onRestoreStateChangeWithState:state restoreContent:restoreContent];
            });
        }
    }
}


- (void)onTerminateRestoreWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTerminateRestoreWithTerminateReason:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTerminateRestoreWithTerminateReason:terminateReason];
            });
        }
    }
}

- (void)onTerminateVerifyWithReport:(nonnull TLVerifyReport *)report {
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTerminateVerifyWithReport:)]) {
            id<TLBackupServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTerminateVerifyWithReport:report];
            });
        }
    }
}

@end
