/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <objc/runtime.h>

#import <CocoaLumberjack.h>

#import "TLVerifyExecutor.h"
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
#import "TLVerifyReport.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLVerifyExecutor"

@interface TLVerifyExecutor ()

@property (nonatomic, nonnull, readonly) NSDictionary<NSUUID *, TLBackupHandler *> *handlers;
@property (nonatomic, nonnull, readonly) TLBackupService *backupService;
@property (nonatomic, nonnull, readonly) TLTwinlife *twinlife;

@property (nonatomic, nonnull, readonly) NSData *password;
@property (nonatomic, readonly) int64_t date;
@property (nonatomic, nullable) TLBackupHeaderInfo *backupHeaderInfo;
@property (nonatomic, nonnull, readonly) NSData *salt;

@property (nonatomic, nonnull, readonly) NSString *backupFilePath;
@property (nonatomic, nonnull, readonly)  NSArray<NSUUID *> *supportedSchemaIds;
@property (nonatomic, nullable) TLBinaryDecoder *decoder;
@property (nonatomic, nonnull, readonly) dispatch_queue_t restoreQueue;

@property (nonatomic, nullable) TLAccountServiceSecuredConfiguration *accountConfiguration;
@property (nonatomic) TLBackupServiceTerminateReason terminateReason;
@property (nonatomic, nullable) TLRestoreContent *restoreContent;

@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *addedObjects;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *deletedObjects;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *modifiedObjects;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSMutableArray<id<TLRepositoryObject>> *> *upToDateObjects;

@property (nonatomic, nonnull, readonly) NSMutableArray<TLBackupVerifyResultPresent<TLTwincodeOutbound *> *> *twincodeOutbounds;

- (void) internalStartVerify;

@end


@implementation TLVerifyExecutor

- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password backupFilePath:(nonnull NSString *)backupFilePath supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds {
    DDLogVerbose(@"%@ initWithBackupService: %@, password: %@ backupFilePath: %@", LOG_TAG, backupService, password, backupFilePath);
    
    self = [super init];
    
    if (self) {
        _backupService = backupService;
        _twinlife = twinlife;
        _password = password;
        _date = [NSDate date].timeIntervalSince1970 * 1000;
        
        _backupFilePath = backupFilePath;
        _supportedSchemaIds = supportedSchemaIds;
                
        _handlers = @{
            TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_ID : [[TLTwincodeOutboundHandler alloc] initWithTwincodeOutboundService:twinlife.twincodeOutboundService cryptoService:twinlife.cryptoService],
            TL_TWINCODE_INBOUND_BACKUP_SCHEMA_ID : [[TLTwincodeInboundHandler alloc] initWithTwincodeInboundService:twinlife.twincodeInboundService twincodeOutboundService:twinlife.twincodeOutboundService],
            TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_ID : [[TLRepositoryObjectHandler alloc] initWithRepositoryService:twinlife.repositoryService supportedSchemaIds:supportedSchemaIds],
            TL_IMAGE_BACKUP_SCHEMA_ID : [[TLImageHandler alloc] initWithTwinlife:twinlife]
        };
        
        _restoreState = TLRestoreStateStarting;
                
        _restoreQueue = dispatch_queue_create("restoreQueue", DISPATCH_QUEUE_SERIAL);

        _addedObjects = [NSMutableDictionary dictionary];
        _deletedObjects = [NSMutableDictionary dictionary];
        _modifiedObjects = [NSMutableDictionary dictionary];
        _upToDateObjects = [NSMutableDictionary dictionary];
        
        _twincodeOutbounds = [NSMutableArray array];
        
        [self.backupService onRestoreStateChangeWithState:_restoreState restoreContent:nil];
    }
        
    return self;
}

- (void)startVerify {
    DDLogVerbose(@"%@ startVerify", LOG_TAG);

    [self executeIfNotCancelledWithBlock:^{
        [self internalStartVerify];
    }];
}

- (void)internalStartVerify {
    DDLogVerbose(@"%@ internalStartVerify", LOG_TAG);
       
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
        TLBackupVerifyResult *header = [[[TLBackupHeaderHandler alloc] initWithFileSignature:[TLBackupService getFileSignature]] verifyWithBinaryDecoder:self.decoder];
        if ([header isKindOfClass:TLBackupVerifyResultAbsent.class]) {
            [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeFileNotSupported];
            return;
        }
        self.backupHeaderInfo = ((TLBackupVerifyResultPresent<TLBackupHeaderInfo *> *)header).object;
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
    
    [self.backupService onBackupHeaderInfoWithHeaderInfo:self.backupHeaderInfo lastBackupId:lastBackupId lastBackupTimestamp:lastBackupTimestamp];

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
    
    // Read Account secured configuration.
    // TLAccountSecuredConfigurationHandler.verifyWithBinaryDecoder always returns TLBackupVerifyResultPresent.
    TLBackupVerifyResultPresent *accountVerify;
    @try {
        accountVerify = (TLBackupVerifyResultPresent *)[[[TLAccountSecuredConfigurationHandler alloc] initWithTwinlife:self.twinlife] verifyWithBinaryDecoder:self.decoder];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Error occurred while restoring account configuration: %@", LOG_TAG, exception.userInfo);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeInvalidFile baseErrorCode:TLBaseServiceErrorCodeDecryptError];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    if (accountVerify.modified) {
        DDLogError(@"%@ Couldn't restore AccountSecuredConfiguration", LOG_TAG);
        [self.backupService onRestoreErrorWithBackupErrorCode:TLBackupServiceErrorCodeDifferentAccount baseErrorCode:TLBaseServiceErrorCodeFileNotSupported];
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonError];
        return;
    }
    
    [self verifyData];
}

- (void)verifyData {
    DDLogVerbose(@"%@ verifyData", LOG_TAG);
    
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
                        TLBackupVerifyResult *result = [handler verifyWithBinaryDecoder:self.decoder];
                        [self handleResultWithResult:result];
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
            
        [self generateReport];
    }];
}

- (void)addUUIDBySchemaIdWithUUIDs:(nonnull NSMutableDictionary<NSUUID *,NSMutableArray<NSUUID *> *> *)UUIDs schemaId:(nonnull NSUUID *)schemaId uuid:(nonnull NSUUID *)uuid {
    NSMutableArray<NSUUID *> *values = UUIDs[schemaId];
    
    if (!values) {
        values = [NSMutableArray array];
        UUIDs[schemaId] = values;
    }
    
    [values addObject:uuid];
}

- (void)addObjectBySchemaIdWithObjects:(nonnull NSMutableDictionary<NSUUID *,NSMutableArray<id<TLRepositoryObject>> *> *)objects schemaId:(nonnull NSUUID *)schemaId object:(nonnull id<TLRepositoryObject>)object {
    NSMutableArray<id<TLRepositoryObject>> *values = objects[schemaId];
    
    if (!values) {
        values = [NSMutableArray array];
        objects[schemaId] = values;
    }
    
    [values addObject:object];
}


- (void)handleResultWithResult:(nonnull TLBackupVerifyResult *)result {
    DDLogVerbose(@"%@ handleResultWithResult: %@", LOG_TAG, result);

    if ([result isKindOfClass:TLBackupVerifyResultPresent.class]) {
        TLBackupVerifyResultPresent *present = (TLBackupVerifyResultPresent *)result;
        
        if ([present.object conformsToProtocol:@protocol(TLRepositoryObject)]) {

            id<TLRepositoryObject> repositoryObject = (id<TLRepositoryObject>)present.object;
            
            if (present.modified) {
                [self addUUIDBySchemaIdWithUUIDs:self.modifiedObjects schemaId:repositoryObject.identifier.schemaId uuid:repositoryObject.objectId];
            } else {
                [self addObjectBySchemaIdWithObjects:self.upToDateObjects schemaId:repositoryObject.identifier.schemaId object:repositoryObject];
            }
        } else if ([present.object isKindOfClass:TLTwincodeOutbound.class]) {
            // Keep twincodes to check if repository objects were modified after reading the entire backup.
            [self.twincodeOutbounds addObject:(TLBackupVerifyResultPresent<TLTwincodeOutbound *> *)present];
        }
    } else {
        TLBackupVerifyResultAbsent *absent = (TLBackupVerifyResultAbsent *)result;
        
        if (class_conformsToProtocol(absent.type, @protocol(TLRepositoryObject))) {
            [self addUUIDBySchemaIdWithUUIDs:self.deletedObjects schemaId:absent.schemaId uuid:absent.identifier];
        }
    }
}

- (void)generateReport {
    DDLogVerbose(@"%@ generateReport", LOG_TAG);
    
    [self findAddedObjects];
    [self findTwincodeUpdates];
    
    NSMutableDictionary<NSUUID *, NSMutableArray<NSUUID *> *> *upToDateIds = [NSMutableDictionary dictionary];
    
    for (NSUUID *schemaId in self.upToDateObjects.allKeys) {
        NSArray<id<TLRepositoryObject>> *objects = self.upToDateObjects[schemaId];
        for (id<TLRepositoryObject> object in objects) {
            [self addUUIDBySchemaIdWithUUIDs:upToDateIds schemaId:schemaId uuid:object.objectId];
        }
    }
    
    TLVerifyReport *report = [[TLVerifyReport alloc] initWithDeleted:self.deletedObjects added:self.addedObjects modified:self.modifiedObjects upToDate:upToDateIds];
    
    [self.backupService onTerminateVerifyWithReport:report];
}

/// Find objects that are in the database but not in the backup.
- (void)findAddedObjects {
    DDLogVerbose(@"%@ findAddedObjects", LOG_TAG);
    
    NSMutableArray<NSUUID *> *activeObjects = [NSMutableArray array];
    
    for (NSArray<id<TLRepositoryObject>> *objects in self.upToDateObjects.allValues) {
        for (id<TLRepositoryObject> object in objects) {
            [activeObjects addObject:object.objectId];
        }
    }
    
    for (NSArray<NSUUID *> *objectIds in self.modifiedObjects.allValues) {
        [activeObjects addObjectsFromArray:objectIds];
    }
    
    for (id<TLRepositoryObject> localObject in [self.twinlife.repositoryService getLocalObjectsWithSupportedSchemaIds:self.supportedSchemaIds]) {
        BOOL found = NO;
        for (NSUUID *objectId in activeObjects) {
            if ([localObject.objectId isEqual:objectId]) {
                found = YES;
                break;
            }
        }
        
        if (!found) {
            [self addUUIDBySchemaIdWithUUIDs:self.addedObjects schemaId:localObject.identifier.schemaId uuid:localObject.objectId];
        }
    }
}

/// Check for objects whose twincode has been updated after the backup.
- (void)findTwincodeUpdates {
    DDLogVerbose(@"%@ findTwincodeUpdates", LOG_TAG);
    
    for (NSMutableArray<id<TLRepositoryObject>> *objects in self.upToDateObjects.allValues) {
        NSMutableArray<id<TLRepositoryObject>> *modifiedObjects = [NSMutableArray array];

        for (id<TLRepositoryObject> object in objects) {
            
            if (!object.twincodeOutbound) {
                continue;
            }
            
            for (TLBackupVerifyResultPresent<TLTwincodeOutbound *> *result in self.twincodeOutbounds) {
                if ([result.object.uuid isEqual:object.twincodeOutbound.uuid]) {
                    if (result.modified) {
                        [modifiedObjects addObject:object];
                        [self addUUIDBySchemaIdWithUUIDs:self.modifiedObjects schemaId:object.identifier.schemaId uuid:object.objectId];
                    }
                    break;
                }
            }
        }
        
        [objects removeObjectsInArray:modifiedObjects];
    }
}

- (void)cancelWithTerminateReason:(TLBackupServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ cancelWithTerminateReason: %d", LOG_TAG, terminateReason);
    
    self.terminateReason = terminateReason;
        
    NSData *inputData = self.decoder.data;
    if ([inputData isKindOfClass:TLCryptoDataInput.class]) {
        [((TLCryptoDataInput *)inputData) close];
    }
                    
    self.restoreState = TLRestoreStateTerminated;
    [self.backupService onTerminateRestoreWithTerminateReason:terminateReason];
}

- (void)executeIfNotCancelledWithBlock:(void (^)(void))block {
    if (self.restoreState == TLRestoreStateCancel) {
        DDLogVerbose(@"%@ Restore cancelled: rollback and exit", LOG_TAG);
        [self cancelWithTerminateReason:TLBackupServiceTerminateReasonCancel];
        return;
    }
    
    dispatch_async(self.restoreQueue, block);
}

@end


