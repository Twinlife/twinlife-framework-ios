/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "TLBackupExecutor.h"
#import "TLBackupHandler.h"
#import "TLAccountSecuredConfigurationHandler.h"
#import "TLBackupHeaderHandler.h"
#import "TLTwincodeOutboundHandler.h"
#import "TLTwincodeInboundHandler.h"
#import "TLRepositoryObjectHandler.h"
#import "TLImageHandler.h"
#import "NSData+Extensions.h"
#import "TLTwinlifeImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLCryptoDataOutput.h"
#import "TLAccountServiceImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SALT_LENGTH 64

#undef LOG_TAG
#define LOG_TAG @"TLBackupExecutor"

static const int SERIALIZER_BUFFER_DEFAULT_SIZE = 1024;

@interface TLBackupExecutor ()

@property (nonatomic, nonnull, readonly) NSArray<TLBackupHandler *> *unencryptedHandlers;
@property (nonatomic, nonnull, readonly) NSArray<TLBackupHandler *> *encryptedHandlers;
@property (nonatomic, nonnull, readonly) TLBackupService *backupService;
@property (nonatomic, nonnull, readonly) TLTwinlife *twinlife;

@property (nonatomic, nonnull, readonly) NSData *password;
@property (nonatomic, readonly) int64_t date;
@property (nonatomic, nonnull, readonly) NSUUID *backupId;
@property (nonatomic, nonnull, readonly) NSData *salt;

@property (nonatomic, nonnull, readonly) NSURL *backupFile;
@property (nonatomic) TLBackupState backupState;
@property (nonatomic, nonnull, readonly) dispatch_queue_t backupQueue;

- (void) internalStartBackup;

@end

@implementation TLBackupExecutor

- (nonnull instancetype)initWithBackupService:(nonnull TLBackupService *)backupService twinlife:(nonnull TLTwinlife *)twinlife password:(nonnull NSData *)password supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds {
    DDLogVerbose(@"%@ initWithBackupService: %@, password: %@", LOG_TAG, backupService, password);
    
    self = [super init];
    
    if (self) {
        _backupService = backupService;
        _twinlife = twinlife;
        _password = password;
        _date = [NSDate date].timeIntervalSince1970 * 1000;
        _backupId = [NSUUID UUID];
        _salt = [NSData secureRandomWithLength:SALT_LENGTH];
                        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"YYYY-MM-dd"];
        
        NSString *uuidString = [_backupId UUIDString];
        NSString *shortUUID = uuidString.length >= 8 ? [uuidString substringToIndex:8] : uuidString;
        
        NSString *fileName = [NSString stringWithFormat:@"backup-%@-%@.%@", shortUUID, [dateFormatter stringFromDate:[NSDate date]], [TLTwinlife BACKUP_EXTENSION]];
        _backupFile = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
        
        BOOL result = [NSFileManager.defaultManager createFileAtPath:_backupFile.path contents:nil attributes:nil];

        if (!result) {
            DDLogError(@"%@ Cannot create backup file %@", LOG_TAG, _backupFile.path);
        }
        
        _unencryptedHandlers = @[
            [[TLBackupHeaderHandler alloc] initWithBackupId:_backupId date:_date salt:_salt applicationName:twinlife.twinlifeConfiguration.applicationName applicationVersion:twinlife.twinlifeConfiguration.applicationVersion fileSignature:[TLBackupService getFileSignature]]
        ];
        
        _encryptedHandlers = @[
            [[TLAccountSecuredConfigurationHandler alloc] initWithTwinlife:twinlife],
            [[TLImageHandler alloc] initWithTwinlife:twinlife],
            [[TLTwincodeOutboundHandler alloc] initWithTwincodeOutboundService:twinlife.twincodeOutboundService cryptoService:twinlife.cryptoService],
            [[TLTwincodeInboundHandler alloc] initWithTwincodeInboundService:twinlife.twincodeInboundService twincodeOutboundService:twinlife.twincodeOutboundService],
            [[TLRepositoryObjectHandler alloc] initWithRepositoryService:twinlife.repositoryService supportedSchemaIds:supportedSchemaIds]
        ];
        
        _backupState = TLBackupStateStarting;
                
        _backupQueue = dispatch_queue_create("backupQueue", DISPATCH_QUEUE_SERIAL);

        [self.backupService onBackupStateChangeWithBackupId:self.backupId state:self.backupState];
    }
        
    return self;
}

- (void)startBackup {
    DDLogVerbose(@"%@ startBackup", LOG_TAG);

    dispatch_async(self.backupQueue, ^{
        [self internalStartBackup];
    });
}

- (void)internalStartBackup {
    DDLogVerbose(@"%@ internalStartBackup", LOG_TAG);
    
    self.backupState = TLBackupStateGenerateKey;
    
    [self.twinlife.accountService generateBackupKeyWithBackupId:self.backupId password:self.password salt:self.salt forRestore:NO withBlock:^(TLBaseServiceErrorCode status, NSData * _Nullable serverKey, NSUUID * _Nullable lastBackupId, int64_t lastBackupTimestamp) {
        [self onGenerateKeyWithStatus:status derivedServerKey:serverKey];
    }];
}

- (void)onGenerateKeyWithStatus:(TLBaseServiceErrorCode)status derivedServerKey:(nullable NSData *)derivedServerKey {
    DDLogVerbose(@"%@ onGenerateKeyWithStatus:%d derivedServerKey:%@", LOG_TAG, status, derivedServerKey);
    
    if (status != TLBaseServiceErrorCodeSuccess || derivedServerKey == nil) {
        [self.backupService onBackupErrorWithBackupErrorCode:TLBackupServiceErrorCodeKeyGenFailed baseErrorCode:status];
        return;
    }
    
    self.backupState = TLBackupStateCreateFile;
    
    [self.backupService onBackupStateChangeWithBackupId:self.backupId state:self.backupState];
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *encoder = [[TLBinaryEncoder alloc] initWithData:data];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.backupFile.path];
    
    for (TLBackupHandler *handler in self.unencryptedHandlers) {
        @try {
            [handler backupWithBinaryEncoder:encoder];
        } @catch (NSException *exception) {
            DDLogError(@"%@ Couldn't encode plaintext backup data: %@", LOG_TAG, exception.userInfo);
            [self.backupService onBackupErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
            return;
        }
    }

    @try {
        [fileHandle writeData:encoder.data];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Couldn't write plaintext backup data: %@", LOG_TAG, exception.userInfo);
        [self.backupService onBackupErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
        [fileHandle closeFile];
        return;
    }
    
    TLCryptoDataOutput *cryptoData = [self.twinlife.cryptoService createCryptoDataOutputWithFileHandle:fileHandle password:derivedServerKey];
    
    if (!cryptoData) {
        DDLogError(@"%@ TLCryptoDataOutput creation failed", LOG_TAG);
        [self.backupService onBackupErrorWithBackupErrorCode:TLBackupServiceErrorCodeKeyGenFailed baseErrorCode:TLBaseServiceErrorCodeEncryptError];
        [fileHandle closeFile];
        return;
    }
    
    encoder = [[TLBinaryEncoder alloc] initWithData:cryptoData];
    
    NSMutableDictionary<NSUUID *, NSNumber *> * stats = [NSMutableDictionary dictionary];
    
    for (TLBackupHandler *handler in self.encryptedHandlers) {
        @try {
            [handler backupWithBinaryEncoder:encoder];
        } @catch (NSException *exception) {
            DDLogError(@"%@ Couldn't encode encrypted backup data (handler=%@): %@", LOG_TAG, handler, exception.userInfo);
            [self.backupService onBackupErrorWithBackupErrorCode:TLBackupServiceErrorCodeIOError baseErrorCode:TLBaseServiceErrorCodeLibraryError];
            [fileHandle closeFile];
            return;
        }
        
        NSDictionary *handlerStats = handler.getBackupStats;
        if (handlerStats) {
            [stats addEntriesFromDictionary:handlerStats];
        }
    }
    
    [cryptoData flushBuffer];

    [fileHandle closeFile];
    DDLogVerbose(@"%@ backup done, file: %@", LOG_TAG, self.backupFile.path);
    
    [self.backupService onTerminateBackupWithBackupId:self.backupId backupFilePath:self.backupFile.path stats:stats];
}

@end

