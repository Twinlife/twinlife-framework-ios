/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "TLRestoreExecutor.h"
#import "TLBackupHandler.h"
#import "TLAccountSecuredConfigurationHandler.h"
#import "TLBackupHeaderHandler.h"
#import "TLTwincodeOutboundHandler.h"
#import "TLTwincodeInboundHandler.h"
#import "TLRepositoryObjectHandler.h"
#import "TLImageHandler.h"
#import "NSData+Extensions.h"
#import "TLTwinlifeImpl.h"
#import "TLAccountServiceImpl.h"
#import "TLImageServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwincodeFactoryServiceImpl.h"
#import "TLRepositoryServiceImpl.h"
#import "TLCryptoDataInput.h"
#import "TLTwincodeInfo.h"
#import "TLRestoreContent.h"
#import "TLTwinlifeContext.h"
#import "TLRepositoryService.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLRestoreExecutor"

@interface TLRestoreExecutor ()

@property (nonatomic, nonnull, readonly) NSDictionary<NSUUID *, TLBackupHandler *> *handlers;
@property (nonatomic, nonnull, readonly) TLBackupService *backupService;
@property (nonatomic, nonnull, readonly) TLTwinlife *twinlife;
@property (nonatomic, nonnull, readonly) TLTwinlifeContext *twinlifeContext;

@property (nonatomic, nonnull, readonly) NSData *password;
@property (nonatomic, readonly) int64_t date;
@property (nonatomic, nullable) TLBackupHeaderInfo *backupHeaderInfo;
@property (nonatomic, nonnull, readonly) NSData *salt;

@property (nonatomic, nonnull, readonly) NSString *backupFilePath;
/// 1 = YES, 0 = NO, nil = decide based on account ID
@property (nonatomic, nullable, readonly) NSNumber *inPlaceRequested;
@property (nonatomic, nonnull, readonly)  NSArray<NSUUID *> *supportedSchemaIds;
@property (nonatomic, nullable) TLBinaryDecoder *decoder;
@property (nonatomic, nonnull, readonly) dispatch_queue_t restoreQueue;

@property (nonatomic, nullable) TLAccountServiceSecuredConfiguration *accountConfiguration;
@property (nonatomic) BOOL inPlaceRestore;
@property (nonatomic) TLBackupServiceTerminateReason terminateReason;
@property (nonatomic, nullable) TLRestoreContent *restoreContent;

@property (nonatomic) int retryReconnect;

@property (nonatomic, nonnull, readonly) NSMutableArray<TLTwincodeInfo *> *addedTwincodes;
@property (nonatomic, nonnull, readonly) NSMutableArray<id<TLRepositoryObject>> *deletedObjects;
@property (nonatomic, nonnull, readonly) NSMutableArray<id<TLRepositoryObject>> *activeObjects;

- (void) internalStartRestore;

@end


@implementation TLRestoreExecutor

- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password backupFilePath:(nonnull NSString *)backupFilePath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds inPlace:(nullable NSNumber *)inPlace twinlifeContext:(nonnull TLTwinlifeContext *)twinlifeContext{
    DDLogVerbose(@"%@ initWithBackupService: %@, password: %@ backupFilePath: %@", LOG_TAG, backupService, password, backupFilePath);
    
    self = [super init];
    
    if (self) {
        _backupService = backupService;
        _twinlife = twinlife;
        _twinlifeContext = twinlifeContext;
        _password = password;
        _date = [NSDate date].timeIntervalSince1970 * 1000;
        
        _backupFilePath = backupFilePath;
        _supportedSchemaIds = supportedSchemaIds;
        _inPlaceRequested = inPlace;
        
        _retryReconnect = 3;
        
        _handlers = @{
            TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_ID : [[TLTwincodeOutboundHandler alloc] initWithTwincodeOutboundService:twinlife.twincodeOutboundService cryptoService:twinlife.cryptoService],
            TL_TWINCODE_INBOUND_BACKUP_SCHEMA_ID : [[TLTwincodeInboundHandler alloc] initWithTwincodeInboundService:twinlife.twincodeInboundService twincodeOutboundService:twinlife.twincodeOutboundService],
            TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_ID : [[TLRepositoryObjectHandler alloc] initWithRepositoryService:twinlife.repositoryService supportedSchemaIds:supportedSchemaIds],
            TL_IMAGE_BACKUP_SCHEMA_ID : [[TLImageHandler alloc] initWithTwinlife:twinlife]
        };
        
        _restoreState = TLRestoreStateStarting;
                
        _restoreQueue = dispatch_queue_create("restoreQueue", DISPATCH_QUEUE_SERIAL);

        _addedTwincodes = [NSMutableArray array];
        _deletedObjects = [NSMutableArray array];
        _activeObjects = [NSMutableArray array];
        
        [self.backupService onRestoreStateChangeWithState:_restoreState restoreContent:nil];
    }
        
    return self;
}

- (void)startRestore {
    DDLogVerbose(@"%@ startRestore", LOG_TAG);

    [self executeIfNotCancelledWithBlock:^{
        [self internalStartRestore];
    }];
}

- (void)internalStartRestore {
    DDLogVerbose(@"%@ internalStartRestore", LOG_TAG);
       
    if (self.password.length == 0) {
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidKey baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        return;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.backupFilePath];
    // Only read a small chunk of data to decode the unencrypted header.
    // We'll read the encrypted data once we have the key in onGenerateBackupKeyWithStatus.
    NSData *backupData = [fileHandle readDataOfLength:(128)];
    [fileHandle closeFile];

    self.decoder = [[TLBinaryDecoder alloc] initWithData:backupData];
    
    @try {
        self.backupHeaderInfo = [[[TLBackupHeaderHandler alloc] initWithFileSignature:[TLBackupService getFileSignature]] restoreWithBinaryDecoder:self.decoder inPlace:self.inPlaceRestore];
    } @catch(NSException *exception) {
        DDLogError(@"%@ Couldn't decode BackupHeaderInfo: %@", LOG_TAG, exception.userInfo);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeFileNotSupported];
        return;
    }
        
    if (!self.backupHeaderInfo) {
        DDLogError(@"%@ Couldn't restore backupHeaderInfo", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeFileNotSupported];
        return;
    }
            
    [self.twinlife.accountService generateBackupKeyWithBackupId:self.backupHeaderInfo.backupId password:self.password salt:self.backupHeaderInfo.salt forRestore:YES withBlock:^(TLBaseServiceErrorCode status, NSData * _Nullable serverKey, NSUUID * _Nullable lastBackupId, int64_t lastBackupTimestamp) {
        [self executeIfNotCancelledWithBlock:^{
            [self onGenerateBackupKeyWithStatus:status serverKey:serverKey lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];
        }];
    }];
}

- (void)onGenerateBackupKeyWithStatus:(TLBaseServiceErrorCode)status serverKey:(nullable NSData *)serverKey lastBackupId:(nullable NSUUID *)lastBackupId lastBackupTimestamp:(int64_t)lastBackupTimestamp {
    DDLogVerbose(@"%@ onGenerateBackupKeyWithStatus:%d serverKey:%@ lastBackupId:%@ lastBackupTimestamp:%lld", LOG_TAG, status, serverKey, lastBackupId, lastBackupTimestamp);

    if (status != TLBaseServiceErrorCodeSuccess || serverKey == nil) {
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeKeyGenFailed baseErrorCode:status];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    // Ignore last backup info: they belong to the currently authenticated account,
    // so if we're restoring a backup made on another device they can't be used to check whether
    // we're restoring the latest backup.
    // We'll get the info from the server once we're authenticated with the account extracted
    // from the backup.
    [self.backupService onBackupHeaderInfoWithHeaderInfo:self.backupHeaderInfo lastBackupId:nil lastBackupTimestamp:-1L];
    
    self.restoreState = TLRestoreStateRestoreAccount;
    [self.backupService onRestoreStateChangeWithState:self.restoreState restoreContent:self.restoreContent];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.backupFilePath];
    
    if (!fileHandle) {
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeFileNotFound];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    // Skip the unencrypted header
    [fileHandle seekToFileOffset:self.decoder.read];
    
    TLCryptoDataInput *cryptoDataInput = [self.twinlife.cryptoService createCryptoDataInputWithFileHandle:fileHandle password:serverKey];
    
    if (!cryptoDataInput) {
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeKeyGenFailed baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    self.decoder = [[TLBinaryDecoder alloc] initWithData:cryptoDataInput];
    
    NSUUID *accountConfId;
    @try {
        accountConfId = [self.decoder readUUID];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Error occurred while restoring account configuration %@", LOG_TAG, exception.userInfo);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidKey baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    if (![accountConfId isEqual:TL_ACCOUNT_CONFIGURATION_BACKUP_SCHEMA_ID]) {
        DDLogError(@"%@ Expected AccountSecuredConfiguration schema ID but got: %@", LOG_TAG, accountConfId);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    // Read Account secured configuration, needed to login with the backed-up account.
    @try {
        self.accountConfiguration = [[[TLAccountSecuredConfigurationHandler alloc] initWithTwinlife:self.twinlife] restoreWithBinaryDecoder:self.decoder inPlace:self.inPlaceRestore];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Error occurred while restoring account configuration: %@", LOG_TAG, exception.userInfo);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    if (!self.accountConfiguration) {
        DDLogError(@"%@ Couldn't restore AccountSecuredConfiguration", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    if (self.inPlaceRequested != nil) {
        self.inPlaceRestore = self.inPlaceRequested.boolValue;
    } else {
        self.inPlaceRestore = [self.twinlife.accountService isCurrentAccountWithAccountConfiguration:self.accountConfiguration];
    }
    
    [self.twinlife.accountService restoreChallengeWithAccountConfiguration:self.accountConfiguration backupId:self.backupHeaderInfo.backupId withBlock:^(TLBaseServiceErrorCode status) {
        [self executeIfNotCancelledWithBlock:^{
            if (status != TLBaseServiceErrorCodeSuccess) {
                DDLogError(@"%@ Restore auth failed: %d", LOG_TAG, status);
                [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeRevoked baseErrorCode:status];
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            [self onRestoreAuthSuccess];
        }];
    }];
}


- (void)onRestoreAuthSuccess {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
        
    // This is our (successful) reconnect attempt, we're logged in with the restored account:
    // restore the DB and images.

    [self executeIfNotCancelledWithBlock:^{
        self.restoreState = TLRestoreStatePrepareDatabase;
        [self.backupService onRestoreStateChangeWithState:self.restoreState restoreContent:self.restoreContent];
        
        if (!self.accountConfiguration) {
            DDLogError(@"%@ No accountConfiguration", LOG_TAG);
            [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:TLBaseServiceErrorCodeLibraryTooOld];
            [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
            return;
        }
        
        TLBaseServiceErrorCode errorCode = [self.twinlife prepareDatabaseForRestoreWithInPlaceRestore:self.inPlaceRestore];
        
        if (errorCode != TLBaseServiceErrorCodeSuccess) {
            DDLogError(@"%@ Error while preparing database for restore: %d", LOG_TAG, errorCode);
            [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:errorCode];
            [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
            return;
        }
        
        [self.twinlife.getAccountService getAllBackupsWithBlock:^(TLBaseServiceErrorCode status, NSArray<TLBackupInfo *> * _Nullable backups) {
            if (status != TLBaseServiceErrorCodeSuccess || backups == nil) {
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            if (backups.count > 0 && self.backupHeaderInfo) {
                TLBackupInfo *lastBackupInfo = nil;
                
                for (TLBackupInfo *backupInfo in backups) {
                    if (!lastBackupInfo || lastBackupInfo.creationDate < backupInfo.creationDate) {
                        lastBackupInfo = backupInfo;
                    }
                }
                
                [self.backupService onBackupHeaderInfoWithHeaderInfo:self.backupHeaderInfo lastBackupId:lastBackupInfo.uuid lastBackupTimestamp:lastBackupInfo.creationDate];
            }
            
            [self restoreData];
        }];
    }];
}

- (void)restoreData {
    DDLogVerbose(@"%@ restoreData", LOG_TAG);
    
    [self executeIfNotCancelledWithBlock:^{
        self.restoreState = TLRestoreStateRestoreData;
        [self.backupService onRestoreStateChangeWithState:self.restoreState restoreContent:self.restoreContent];
        
        if (!self.decoder) {
            DDLogError(@"%@ onSignIn: self.decoder is nil", LOG_TAG);
            [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
            [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
            return;
        }
        
        TLCryptoDataInput *input = (TLCryptoDataInput *)self.decoder.data;
        
        while (!input.fullyRead) {
            if (self.restoreState != TLRestoreStateCancel) {
                @try {
                    NSUUID *schemaId = [self.decoder readUUID];
                    TLBackupHandler *handler = self.handlers[schemaId];
                    
                    if (!handler) {
                        DDLogWarn(@"%@ No handler found for schemaId: %@", LOG_TAG, schemaId.UUIDString);
                        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeDecryptError];
                        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                        return;
                    } else {
                        // TODO BKP detect errors and rollback
                        [handler restoreWithBinaryDecoder:self.decoder inPlace:self.inPlaceRestore];
                    }
                } @catch (NSException *exception) {
                    DDLogError(@"%@ Error occurred while restoring data: %@", LOG_TAG, exception.userInfo);
                    [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeDecryptError];
                    [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                    return;
                }
            } else {
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonCancel];
                return;
            }
        }
        
        [input close];
            
        NSMutableDictionary<NSUUID *, NSNumber *> *stats = [NSMutableDictionary dictionary];
        
        for (TLBackupHandler *handler in self.handlers.allValues) {
            NSDictionary<NSUUID *, NSNumber *> *handlerstats = handler.getRestoreStats;
            
            if (handlerstats) {
                [stats addEntriesFromDictionary:handlerstats];
            }
        }
        

        [self checkTwincodeConsistency];
    }];
}

- (void)checkTwincodeConsistency {
    DDLogVerbose(@"%@ checkTwincodeConsistency", LOG_TAG);

    self.restoreState = TLRestoreStateGetAllTwincodes;
        
    TLTwincodeOutboundService *twincodeService = self.twinlife.twincodeOutboundService;
    
    [twincodeService getAllTwincodesWithBlock:^(TLBaseServiceErrorCode status, NSDictionary<NSUUID *,NSArray<TLTwincodeInfo *> *> *serverTwincodes) {
        [self executeIfNotCancelledWithBlock:^{
            if (status == TLBaseServiceErrorCodeTwinlifeOffline) {
                DDLogVerbose(@"%@ Device is offline, waiting for server connection to try again.", LOG_TAG);
                return;
            }
            
            self.restoreState = TLRestoreStateCheckConsistency;
                        
            if (status != TLBaseServiceErrorCodeSuccess || !serverTwincodes) {
                DDLogError(@"%@ Error occurred while getting twincodes: status=%d", LOG_TAG, status);
                [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:status];
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            DDLogVerbose(@"%@ Got %lu server twincodes", LOG_TAG, (unsigned long)serverTwincodes.count);
            
            NSArray<TLTwincodeOutbound *> *localTwincodes = [twincodeService getLocalTwincodes];
            DDLogVerbose(@"%@ Got %lu local twincodes", LOG_TAG, localTwincodes.count);
            
            NSArray<id<TLRepositoryObject>> *localObjects = [self.twinlife.repositoryService getLocalObjectsWithSupportedSchemaIds:self.supportedSchemaIds];

            
            NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *activeTwincodeIds = [NSMutableDictionary dictionary];
            
            NSMutableArray<TLTwincodeOutbound *> *onlyLocalTwincodes = [NSMutableArray array];
            
            for (TLTwincodeOutbound *localTwincode in localTwincodes) {
                BOOL active = NO;

                for (NSUUID *schemaId in serverTwincodes.allKeys) {
                    NSArray<TLTwincodeInfo *> *twincodeInfos = serverTwincodes[schemaId];
                    
                    for (TLTwincodeInfo *twincodeInfo in twincodeInfos) {
                        if ([twincodeInfo.twincodeOutboundId isEqual:localTwincode.uuid]) {
                            NSMutableArray<NSUUID *> *twincodeIds = activeTwincodeIds[schemaId];
                            if (!twincodeIds) {
                                twincodeIds = [NSMutableArray array];
                                activeTwincodeIds[schemaId] = twincodeIds;
                            }
                            [twincodeIds addObject:localTwincode.uuid];
                            active = YES;
                            break;
                        }
                    }
                    
                    if (active) {
                        break;
                    }
                }
                
                if (!active) {
                    BOOL owner = NO;
                    for (id<TLRepositoryObject> localObject in localObjects) {
                        TLTwincodeOutbound *objectTwincode = localObject.twincodeOutbound;
                        if (objectTwincode && [objectTwincode.uuid isEqual:localTwincode.uuid]) {
                            owner = YES;
                            break;
                        }
                    }
                    
                    if (owner) {
                        // This twincode belongs to us, include it in the report.
                        [onlyLocalTwincodes addObject:localTwincode];
                    }
                }
            }
            
            NSMutableDictionary<NSUUID *, NSMutableArray<TLTwincodeInfo *> *> *onlyServerTwincodes = [NSMutableDictionary dictionary];
            
            for (NSUUID *schemaId in serverTwincodes.allKeys) {
                NSArray<TLTwincodeInfo *> *serverTwincodeInfos = serverTwincodes[schemaId];
                
                for (TLTwincodeInfo *serverTwincodeInfo in serverTwincodeInfos) {
                    BOOL active = NO;
                    for (TLTwincode *localTwincode in localTwincodes) {
                        if ([serverTwincodeInfo.twincodeOutboundId isEqual:localTwincode.uuid]) {
                            active = YES;
                            break;
                        }
                    }
                    
                    if (!active) {
                        NSMutableArray<TLTwincodeInfo *> *twincodeInfos = onlyServerTwincodes[schemaId];
                        
                        if (!twincodeInfos) {
                            twincodeInfos = [NSMutableArray array];
                            onlyServerTwincodes[schemaId] = twincodeInfos;
                        }
                        
                        [twincodeInfos addObject:serverTwincodeInfo];
                    }
                }
            }
            
            NSUUID *nullUUID = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];

            
            NSArray<TLTwincodeInfo *> *oldServerTwincodes = serverTwincodes[nullUUID];
            if (oldServerTwincodes && oldServerTwincodes.count > 0) {
                DDLogWarn(@"%@ Old twincodes without schema ID found on server but not in the backup: %lu", LOG_TAG, oldServerTwincodes.count);
            }
            
            // Find only-local twincodes schema ID by searching for their corresponding repository object's schema ID.
            NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *onlyLocal = [NSMutableDictionary dictionary];
            for (TLTwincodeOutbound *localTwincode in onlyLocalTwincodes) {
                for (id<TLRepositoryObject> object in localObjects) {
                    TLTwincodeOutbound *objectTwincode = object.twincodeOutbound;
                    if (objectTwincode && [objectTwincode.uuid isEqual:localTwincode.uuid]) {
                        NSUUID *schemaId = object.identifier.schemaId;
                        NSMutableArray<NSUUID *> *twincodeIds = onlyLocal[schemaId];
                        if (!twincodeIds) {
                            twincodeIds = [NSMutableArray array];
                            onlyLocal[schemaId] = twincodeIds;
                        }
                        [twincodeIds addObject:localTwincode.uuid];
                        break;
                    }
                }
            }
            
            NSArray<NSUUID *> *oldActiveTwincodes = activeTwincodeIds[nullUUID];
            if (oldActiveTwincodes) {
                for (NSUUID *oldTwincodeId in oldActiveTwincodes) {
                    for (id<TLRepositoryObject> object in localObjects) {
                        TLTwincodeOutbound *objectTwincode = object.twincodeOutbound;
                        if (objectTwincode && [objectTwincode.uuid isEqual:oldTwincodeId]) {
                            NSUUID *schemaId = object.identifier.schemaId;
                            NSMutableArray<NSUUID *> *twincodeIds = activeTwincodeIds[schemaId];
                            if (!twincodeIds) {
                                twincodeIds = [NSMutableArray array];
                                activeTwincodeIds[schemaId] = twincodeIds;
                            }
                            [twincodeIds addObject:oldTwincodeId];
                            break;
                        }
                    }
                }
            }
            
            self.restoreContent = [[TLRestoreContent alloc] initWithAdded:onlyServerTwincodes deleted:onlyLocal upToDate:activeTwincodeIds];
            
            DDLogVerbose(@"%@ Twincode consistency check results:", LOG_TAG);
            DDLogVerbose(@"%@     added: %lu", LOG_TAG, self.restoreContent.getAddedTwincodeInfos.count);
            DDLogVerbose(@"%@     deleted: %lu", LOG_TAG, self.restoreContent.getDeletedTwincodeIds.count);
            DDLogVerbose(@"%@     upToDate: %lu", LOG_TAG, self.restoreContent.getUpToDateTwincodeIds.count);
            
            self.restoreState = TLRestoreStateWaitConfirm;
            [self.backupService onRestoreStateChangeWithState:self.restoreState restoreContent:self.restoreContent];
        }];
    }];
}

- (void)cancelWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ cancelWithTerminateReason: %d", LOG_TAG, terminateReason);
    
    if (self.restoreState == TLRestoreStateTerminated) {
        return;
    }
    
    [self.twinlife.accountService removeRestoreAccountConfiguration];
    
    self.terminateReason = terminateReason;
        
    NSData *inputData = self.decoder.data;
    if ([inputData isKindOfClass:TLCryptoDataInput.class]) {
        [((TLCryptoDataInput *)inputData) close];
    }
    
    [self.twinlife.accountService rollbackRestoreWithBlock:^(TLBaseServiceErrorCode status, int incarnationCount) {
        // NOOP, the restore is canceled so we don't update the incarnation count.
    }];

    BOOL dbDeleted = [self.twinlife deleteRestoredDatabase];
    
    if (!dbDeleted) {
        DDLogError(@"%@ Could not delete restored DB", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeDatabaseError];
    }
    
    TLBaseServiceErrorCode imageDeletedErrorCode = [self.twinlife.imageService deleteRestoredImages];
    
    if (imageDeletedErrorCode != TLBaseServiceErrorCodeSuccess) {
        DDLogError(@"%@ Could not delete restored images", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
    }
                
    self.restoreState = TLRestoreStateTerminated;
    [self.backupService onTerminateRestoreWithTerminateReason:terminateReason];
    
    // Disconnect to reset the server-side session
    [self.twinlife disconnect];
}

- (void)commit {
    DDLogVerbose(@"%@ commit", LOG_TAG);
    
    [self executeIfNotCancelledWithBlock:^{
        self.restoreState = TLRestoreStateCommit;
        [self.backupService onRestoreStateChangeWithState:self.restoreState restoreContent:self.restoreContent];
        
        [self.twinlife.accountService commitRestoreWithBlock:^(TLBaseServiceErrorCode status, int incarnationCount) {
            
            if (status != TLBaseServiceErrorCodeSuccess) {
                DDLogError(@"%@ Error while committing restore: %d", LOG_TAG, status);
                
                if (status == TLBaseServiceErrorCodeTwinlifeOffline) {
                    if (!self.accountConfiguration || !self.backupHeaderInfo) {
                        DDLogError(@"%@ Missing data to retry auth: accountConfiguration=%@, backupHeaderInfo=%@", LOG_TAG, self.accountConfiguration, self.backupHeaderInfo);
                    } else if (self.retryReconnect-- > 0){
                        [self.twinlife.accountService onDisconnect];
                        [self.twinlife.accountService restoreChallengeWithAccountConfiguration:self.accountConfiguration backupId:self.backupHeaderInfo.backupId withBlock:^(TLBaseServiceErrorCode status) {
                            [self commit];
                        }];
                        return;
                    }
                }
                
                [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:status];
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            TLAccountServiceSecuredConfiguration *accountConfiguration = self.accountConfiguration;
            
            if (!accountConfiguration) {
                DDLogError(@"%@ Error while committing restore: no SecuredAccountConfiguration", LOG_TAG);
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            TLBaseServiceErrorCode imagesErrorCode = [self.twinlife.getImageService commitRestoredImages];

            if (imagesErrorCode != TLBaseServiceErrorCodeSuccess) {
                if (imagesErrorCode == TLBaseServiceErrorCodeFileNotFound && self.inPlaceRestore) {
                    DDLogInfo(@"%@ restored images directory not found. This likely means all images are already on the device.", LOG_TAG);
                } else {
                    DDLogError(@"%@ Error while committing restored images: %d", LOG_TAG, imagesErrorCode);
                    [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                    return;
                }
            }
            
            BOOL dbMoveSuccess = [self.twinlife commitRestoredDatabase];

            if (!dbMoveSuccess) {
                DDLogError(@"%@ Could not move restored DB to main DB", LOG_TAG);
                [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
                return;
            }
            
            [self.twinlife.accountService removeRestoreAccountConfiguration];
            [self.twinlife.accountService restoreAccountSecuredConfigurationWithAccountConfiguration:accountConfiguration restoreCount:incarnationCount];
            
            [self prepareObjectsForUpdate];
            [self updateObjectsAfterRestore];
        }];
    }];
}

- (void)prepareObjectsForUpdate {
    DDLogVerbose(@"%@ prepareObjectsForUpdate", LOG_TAG);
    
    self.restoreState = TLRestoreStateSyncingObjects;
    
    if (!self.restoreContent) {
        DDLogError(@"%@ restoreContent is nil", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
        return;
    }

    [self.addedTwincodes removeAllObjects];
    [self.deletedObjects removeAllObjects];
    [self.activeObjects removeAllObjects];
    
    [self.addedTwincodes addObjectsFromArray:self.restoreContent.getAddedTwincodeInfos];
    
    NSArray<NSUUID *> *onlyOnDeviceTwincodeIds = self.restoreContent.getDeletedTwincodeIds;
    
    NSArray<id<TLRepositoryObject>> *objects = [self.twinlife.repositoryService getLocalObjectsWithSupportedSchemaIds:self.supportedSchemaIds];
    for (id<TLRepositoryObject> object in objects) {
        // Ignore objects without twincodeOutbounds (space, space settings)
        if (object.twincodeOutbound) {
            if ([onlyOnDeviceTwincodeIds containsObject:object.twincodeOutbound.uuid]) {
                [self.deletedObjects addObject:object];
            } else {
                [self.activeObjects addObject:object];
            }
        }
    }
}

- (void)updateObjectsAfterRestore {
    DDLogVerbose(@"%@ updateObjectsAfterRestore", LOG_TAG);
    
    if (!self.restoreContent) {
        DDLogError(@"%@ self.restoreContent is null", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInternalError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
        return;
    }
    
    NSArray<TLTwincodeInfo *> *serverTwincodes = [self.addedTwincodes copy];
    
    for (TLTwincodeInfo *twincodeInfo in serverTwincodes) {
        [self.twinlife.twincodeFactoryService deleteTwincodeWithFactoryId:twincodeInfo.twincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable twincodeFactoryId) {
            [self executeIfNotCancelledWithBlock:^{
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    DDLogError(@"%@ Error deleting twincodeFactory %@: %d", LOG_TAG, twincodeInfo.twincodeFactoryId.UUIDString, errorCode);
                } else {
                    DDLogVerbose(@"%@ Deleted twincodeFactory: %@", LOG_TAG, twincodeInfo.twincodeFactoryId.UUIDString);
                }
                
                if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                    //wait for reconnection
                    return;
                }
                
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeSyncFailed baseErrorCode:errorCode];
                }
                
               
                [self.addedTwincodes removeObject:twincodeInfo];
                [self checkIfSyncingDone];
            }];
        }];
    }
    
    NSArray<id<TLRepositoryObject>> *deviceObjects = [self.deletedObjects copy];
    for (id<TLRepositoryObject> object in deviceObjects) {
        [self.twinlife.repositoryService deleteObjectAfterRestoreWithTwinlifeContext:self.twinlifeContext object:object withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable deletedObject) {
            [self executeIfNotCancelledWithBlock:^{
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    DDLogError(@"%@ Error deleting object %@: %d", LOG_TAG, object, errorCode);
                } else {
                    DDLogVerbose(@"%@ Deleted object: %@", LOG_TAG, object);
                }
                
                if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                    //wait for reconnection
                    return;
                }
                
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeSyncFailed baseErrorCode:errorCode];
                }
                
               
                [self.deletedObjects removeObject:object];
                [self checkIfSyncingDone];
            }];
        }];
    }
    
    
    
    NSArray<id<TLRepositoryObject>> *activeObjects = [self.activeObjects copy];
    for (id<TLRepositoryObject> object in activeObjects) {
        [self.twinlife.repositoryService syncObjectAfterRestoreWithTwinlifecontext:self.twinlifeContext object:object withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable deletedObject) {
            [self executeIfNotCancelledWithBlock:^{
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    DDLogError(@"%@ Error syncing object %@: %d", LOG_TAG, object, errorCode);
                } else {
                    DDLogVerbose(@"%@ Synced object: %@", LOG_TAG, object);
                }
                
                if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                    //wait for reconnection
                    return;
                }
                
                if (errorCode != TLBaseServiceErrorCodeSuccess) {
                    [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeSyncFailed baseErrorCode:errorCode];
                }
               
                [self.activeObjects removeObject:object];
                [self checkIfSyncingDone];
            }];
        }];
    }
}

- (void)checkIfSyncingDone {
    if(self.addedTwincodes.count == 0 && self.deletedObjects.count == 0 && self.activeObjects.count == 0) {
        self.restoreState = TLRestoreStateTerminated;
        self.terminateReason = TLBackupServiceTerminateReasonSuccess;
        [self.backupService onTerminateRestoreWithTerminateReason:TLBackupServiceTerminateReasonSuccess];
    }
}

- (void)onTwinlifeOnline {
    [self executeIfNotCancelledWithBlock:^{
        if (self.restoreState == TLRestoreStateGetAllTwincodes) {
            [self checkTwincodeConsistency];
        } else if (self.restoreState == TLRestoreStateSyncingObjects) {
            [self updateObjectsAfterRestore];
        }
    }];
}

- (void)executeIfNotCancelledWithBlock:(void (^)(void))block {
    TLRestoreState restoreState = self.restoreState;
    
    if (restoreState == TLRestoreStateTerminated) {
        DDLogVerbose(@"%@ Restore terminated: exit", LOG_TAG);
        return;
    }
    
    if (restoreState == TLRestoreStateCancel) {
        DDLogVerbose(@"%@ Restore cancelled: rollback and exit", LOG_TAG);
        dispatch_async(self.restoreQueue, ^{
            [self cancelWithTerminateReason:TLBackupServiceTerminateReasonCancel];
        });
        return;
    }
    
    dispatch_async(self.restoreQueue, block);
}

@end
