/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>
#import <Foundation/Foundation.h>
#import <FMDatabase.h>
#import <FMDatabaseQueue.h>
#import <FMDatabaseAdditions.h>

#define SQLITE_HAS_CODEC // Get access to the sqlite3_key() function.
#import <sqlite3.h>

#import "TLAccountMigrationExecutor.h"
#import "TLAccountMigrationService.h"
#import "TLAccountServiceSecuredConfiguration.h"
#import "TLTwinlifeSecuredConfiguration.h"
#import "TLManagementService.h"
#import "TLJobServiceImpl.h"
#import "TLDatabaseService.h"
#import "TLFileInfo.h"
#import "TLReceivingFileInfo.h"
#import "TLSendingFileInfo.h"
#import "TLSerializerFactoryImpl.h"
#import "TLBinaryDecoder.h"
#import "TLQueryStatsIQ.h"
#import "TLListFilesIQ.h"
#import "TLStartIQ.h"
#import "TLPutFileIQ.h"
#import "TLSettingsIQ.h"
#import "TLAccountIQ.h"
#import "TLTerminateMigrationIQ.h"
#import "TLShutdownIQ.h"
#import "TLErrorIQ.h"
#import "TLOnQueryStatsIQ.h"
#import "TLOnListFilesIQ.h"
#import "TLOnPutFileIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLPeerConnectionHandler.h"
#import "TLKeyChain.h"
#import "TLJobService.h"
#import "TLConfigIdentifier.h"

#if 0
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define MAX_FILES_PER_IQ 64
#define MAX_PENDING_REQUESTS 64
#define DATA_CHUNK_SIZE (64 * 1024)
#define REQUEST_TIMEOUT (30 / 2)
// Specific file indexes for the database file transfer.
#define DATABASE_FILE_INDEX 1
#define DATABASE_CIPHER_3_FILE_INDEX 2
#define DATABASE_CIPHER_4_FILE_INDEX 3
#define DATABASE_CIPHER_5_FILE_INDEX 4
// Note we can have holes in file indexes.
#define FIRST_FILE_INDEX 10

#define EXIT_AFTER_SHUTDOWN_DELAY (100) // wait 100ms after going in background before calling exit(0)

// The two devices must use request Ids that don't overlap because we wait
// for some specific responses sent to the peer and we could clear the
// pendingIQRequests when we receive another message.  This is critical
// for the SendAccount/WaitAccount phase.  Since requestIds are 64-bits,
// set the upper part for one of them.
#define REQUEST_ID_OFFSET_INITIATOR (1LL << 32)
#define REQUEST_ID_OFFSET_CLIENT    (1LL << 33)

// Map some statistics
#define IQ_STAT_QUERY           TLPeerConnectionServiceStatTypeIqSetPushObject
#define IQ_STAT_ON_QUERY        TLPeerConnectionServiceStatTypeIqResultPushObject
#define IQ_STAT_LIST_FILES      TLPeerConnectionServiceStatTypeIqSetPushFile
#define IQ_STAT_ON_LIST_FILES   TLPeerConnectionServiceStatTypeIqResultPushFile
#define IQ_STAT_PUT_FILE        TLPeerConnectionServiceStatTypeIqSetPushFileChunk
#define IQ_STAT_ON_PUT_FILE     TLPeerConnectionServiceStatTypeIqResultPushFileChunk
#define IQ_STAT_SETTINGS        TLPeerConnectionServiceStatTypeIqSetInviteGroup
#define IQ_STAT_START           TLPeerConnectionServiceStatTypeIqSetPushTwincode
#define IQ_STAT_ACCOUNT         TLPeerConnectionServiceStatTypeIqSetPushGeolocation
#define IQ_STAT_TERMINATE       TLPeerConnectionServiceStatTypeIqSetResetConversation
#define IQ_STAT_SHUTDOWN        TLPeerConnectionServiceStatTypeIqSetLeaveGroup
#define IQ_STAT_ERROR           TLPeerConnectionServiceStatTypeIqResultPushTwincode

#define QUERY_STAT_SCHEMA_ID            @"4b201b06-7952-43a4-8157-96b9aeffa667"
#define LIST_FILES_SCHEMA_ID            @"5964dbf0-5620-4c78-963b-c6e08665fc33"
#define START_SCHEMA_ID                 @"8a26fefe-6bd5-45e2-9098-3d736d8a1c4e"
#define PUT_FILE_SCHEMA_ID              @"ccc791c2-3a5c-4d83-ab06-48137a4ad262"
#define SETTINGS_SCHEMA_ID              @"09557d03-3af7-4151-aa60-c6a4b992e18b"
#define SWAP_ACCOUNT_SCHEMA_ID          @"11161f66-68e9-4cb4-8c12-241f4e071af4"
#define TERMINATE_MIGRATION_SCHEMA_ID   @"a35089f8-326f-4f25-b160-e0f9f2c9795c"
#define SHUTDOWN_SCHEMA_ID              @"05c90756-d56c-4e2f-92bf-36b2d3f31b76"
#define ERROR_SCHEMA_ID                 @"42705574-8e05-47fd-9742-ffd86a923cea"

#define ON_QUERY_STAT_SCHEMA_ID         @"0906f883-6adf-4d90-9252-9ab401fbe531"
#define ON_LIST_FILES_SCHEMA_ID         @"e74fea73-abc7-42ca-ad37-b636f6c4df2b"
#define ON_PUT_FILE_SCHEMA_ID           @"ef7b3c03-33d5-49c2-8644-79ea2688403e"

static TLBinaryPacketIQSerializer *IQ_QUERY_STAT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_LIST_FILES_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_START_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PUT_FILE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SETTINGS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SWAP_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TERMINATE_MIGRATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SHUTDOWN_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ERROR_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_ON_QUERY_STAT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_LIST_FILES_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_PUT_FILE_SERIALIZER = nil;


@interface TLAccountMigrationExecutorPeerConnectionServiceDelegate : NSObject <TLPeerConnectionServiceDelegate>

@property (weak) TLAccountMigrationExecutor *accountMigrationExecutor;

- (instancetype)initWithAccountMigrationExecutor:(TLAccountMigrationExecutor *)accountMigrationExecutor;

@end

#undef LOG_TAG
#define LOG_TAG @"TLAccountMigrationExecutorPeerConnectionServiceDelegate"

@implementation TLAccountMigrationExecutorPeerConnectionServiceDelegate

- (instancetype)initWithAccountMigrationExecutor:(TLAccountMigrationExecutor *)accountMigrationExecutor {
    self = [super init];
    
    if (self) {
        _accountMigrationExecutor = accountMigrationExecutor;
    }
    
    return self;
}

@end

@interface TLAccountMigrationExecutor () <TLPeerConnectionServiceDelegate, TLJob, TLBackgroundJobObserver>

@property (nonatomic, nonnull, readonly) TLPeerConnectionHandler *handler;

@property (nonatomic, nonnull, readonly) TLManagementService *managementService;
@property (nonatomic, nonnull, readonly) TLAccountMigrationService *accountMigrationService;
@property (nonatomic, nonnull, readonly) NSMutableSet<NSNumber *> *pendingIQRequests;
@property (nonatomic, nonnull, readonly) NSMutableArray<TLFileInfo *> *listFiles;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSNumber *, TLFileInfo *> *waitListFiles;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSNumber *, TLFileInfo *> *sendingFiles;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSNumber *, TLFileInfo *> *receivingFiles;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSNumber *, TLFileInfo *> *waitAckFiles;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSNumber *, TLReceivingFileInfo *> *receivingStreams;
@property (nonatomic, nonnull, readonly) TLDatabaseService *databaseService;

// No need for ConfigurationService : use TLKeyChain's static method to load configs directly.
@property (nonatomic, nonnull, readonly) NSURL *rootDirectory;
@property (nonatomic, nonnull, readonly) NSURL *migrationDirectory;
@property (nonatomic, nonnull, readonly) NSURL *databaseFile;

@property (nonatomic, readonly) int databaseFileIndex;
@property (nonatomic) int fileIndex;
@property (nonatomic) int64_t maxFileSize;
@property (nonatomic) int64_t sent;
@property (nonatomic) int64_t received;
@property (nonatomic) int64_t sendTotal;
@property (nonatomic) int64_t receiveTotal;
@property (nonatomic) int64_t sendPending;
@property (nonatomic) int64_t receivePending;
@property (nonatomic) int receiveErrorCount;
@property (nonatomic) int sendErrorCount;
@property (nonatomic, nullable) TLSendingFileInfo *sendingFile;
@property (nonatomic) int64_t lastReport;
@property (nonatomic) BOOL needRestart;
@property (nonatomic) BOOL accountReceived;
@property (nonatomic) BOOL accountSent;
@property (nonatomic) BOOL settingsSent;
@property (nonatomic) BOOL settingsReceived;
@property (nonatomic) BOOL requestTimeoutExpired;
@property (nonatomic) TLAccountMigrationErrorCode currentError;
@property (nonatomic) int64_t offsetRequestId;
@property (nonatomic, nullable) TLTwinlifeSecuredConfiguration *secureConfiguration;
@property (nonatomic, nullable) NSString *migrationDatabasePath;

@property (nonatomic, nullable) TLQueryInfo *peerInfo;
@property (nonatomic, nullable) TLQueryInfo *localInfo;

@property (nonatomic, nonnull, readonly) NSFileManager *fileManager;

@property (nonatomic, nullable) TLJobId *requestTimeout;
@end


#undef LOG_TAG
#define LOG_TAG @"TLAccountMigrationExecutor"

@implementation TLAccountMigrationExecutor


+ (void)initialize {
    
    IQ_QUERY_STAT_SERIALIZER = [[TLQueryStatsIQSerializer alloc] initWithSchema:QUERY_STAT_SCHEMA_ID schemaVersion:1];
    IQ_LIST_FILES_SERIALIZER = [[TLListFilesIQSerializer alloc] initWithSchema:LIST_FILES_SCHEMA_ID schemaVersion:1];
    IQ_START_SERIALIZER = [[TLStartIQSerializer alloc] initWithSchema:START_SCHEMA_ID schemaVersion:1];
    IQ_PUT_FILE_SERIALIZER = [[TLPutFileIQSerializer alloc] initWithSchema:PUT_FILE_SCHEMA_ID schemaVersion:1];
    IQ_SETTINGS_SERIALIZER = [[TLSettingsIQSerializer alloc] initWithSchema:SETTINGS_SCHEMA_ID schemaVersion:1];
    IQ_SWAP_ACCOUNT_SERIALIZER = [[TLSwapAccountIQSerializer alloc] initWithSchema:SWAP_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_TERMINATE_MIGRATION_SERIALIZER = [[TLTerminateMigrationIQSerializer alloc] initWithSchema:TERMINATE_MIGRATION_SCHEMA_ID schemaVersion:1];
    IQ_SHUTDOWN_SERIALIZER = [[TLShutdownIQSerializer alloc] initWithSchema:SHUTDOWN_SCHEMA_ID schemaVersion:1];
    IQ_ERROR_SERIALIZER = [[TLMigrationErrorIQSerializer alloc] initWithSchema:ERROR_SCHEMA_ID schemaVersion:1];

    IQ_ON_QUERY_STAT_SERIALIZER = [[TLOnQueryStatsIQSerializer alloc] initWithSchema:ON_QUERY_STAT_SCHEMA_ID schemaVersion:1];
    IQ_ON_LIST_FILES_SERIALIZER = [[TLOnListFilesIQSerializer alloc] initWithSchema:ON_LIST_FILES_SCHEMA_ID schemaVersion:1];
    IQ_ON_PUT_FILE_SERIALIZER = [[TLOnPutFileIQSerializer alloc] initWithSchema:ON_PUT_FILE_SCHEMA_ID schemaVersion:1];
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife accountMigrationService:(nonnull TLAccountMigrationService *)accountMigrationService databaseService:(nonnull TLDatabaseService *)databaseService databaseFile:(nonnull NSURL *)databaseFile accountMigrationId:(nonnull NSUUID *)accountMigrationId peerId:(nonnull NSString *)peerId rootDirectory:(nonnull NSURL *)rootDirectory {
    self = [super initWithTwinlife:twinlife peerId:peerId];
    
    if (self) {
        _accountMigrationService = accountMigrationService;
        _managementService = [twinlife getManagementService];
        _accountMigrationId = accountMigrationId;
        _pendingIQRequests = [[NSMutableSet alloc] init];
        _listFiles = [[NSMutableArray alloc] init];
        _sendingFiles = [[NSMutableDictionary alloc] init];
        _receivingFiles = [[NSMutableDictionary alloc] init];
        _waitListFiles = [[NSMutableDictionary alloc] init];
        _waitAckFiles = [[NSMutableDictionary alloc] init];
        _receivingStreams = [[NSMutableDictionary alloc] init];
        _rootDirectory = rootDirectory;
        _databaseService = databaseService;
        _databaseFile = databaseFile;
        _state = TLAccountMigrationStateStarting;
        
        _sent = 0;
        _received = 0;
        _sendTotal = 0;
        _receiveTotal = 0;
        _sendPending = 0;
        _receivePending = 0;
        _sendErrorCount = 0;
        _receiveErrorCount = 0;
        _lastReport = 0;
        _needRestart = NO;
        _accountSent = NO;
        _accountReceived = NO;
        _settingsSent = NO;
        _settingsReceived = NO;
        _requestTimeoutExpired = NO;
        _currentError = TLAccountMigrationErrorCodeNone;
        _offsetRequestId = 0;
        _fileIndex = FIRST_FILE_INDEX;
        
        _fileManager = [NSFileManager defaultManager];
        const char *executorQueueName = "migrationExecutorQueue";
        _executorQueue = dispatch_queue_create(executorQueueName, DISPATCH_QUEUE_SERIAL);

        // We only send a cipher V5 format (same as Android V4 but with clear header).
        _databaseFileIndex = DATABASE_CIPHER_5_FILE_INDEX;
        
        _migrationDirectory = [rootDirectory URLByAppendingPathComponent:MIGRATION_DIR];
        
        __weak TLAccountMigrationExecutor *handler = self;
        [self addPacketListener:IQ_QUERY_STAT_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onQueryStatsWithIQ:iq];
        }];
        [self addPacketListener:IQ_ON_QUERY_STAT_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onOnQueryStatsWithIQ:iq];
        }];
        [self addPacketListener:IQ_START_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onStartWithIQ:iq];
        }];
        [self addPacketListener:IQ_LIST_FILES_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onListFilesWithIQ:iq];
        }];
        [self addPacketListener:IQ_ON_LIST_FILES_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onOnListFilesWithIQ:iq];
        }];
        [self addPacketListener:IQ_PUT_FILE_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onPutFileWithIQ:iq];
        }];
        [self addPacketListener:IQ_ON_PUT_FILE_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onOnPutFileWithIQ:iq];
        }];
        [self addPacketListener:IQ_SETTINGS_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onSettingsWithIQ:iq];
        }];
        [self addPacketListener:IQ_SWAP_ACCOUNT_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onSwapAccountWithIQ:iq];
        }];
        [self addPacketListener:IQ_TERMINATE_MIGRATION_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onTerminateMigrationWithIQ:iq];
        }];
        [self addPacketListener:IQ_SHUTDOWN_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onShutdownWithIQ:iq];
        }];
        [self addPacketListener:IQ_ERROR_SERIALIZER listener:^(TLBinaryPacketIQ * _Nonnull iq) {
            [handler onErrorWithIQ:iq];
        }];
        
        //Create the migration id file so that we can easily find the current migration id if we are interrupted.
        NSError *error;
        if (![_fileManager fileExistsAtPath:_migrationDirectory.path] && ![_fileManager createDirectoryAtURL:_migrationDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogWarn(@"%@ Cannot create %@: %@", LOG_TAG, _migrationDirectory.path, error.localizedFailureReason);
            _receiveErrorCount++;
        }
        
        error = nil;
        [_accountMigrationId.UUIDString writeToURL:[_migrationDirectory URLByAppendingPathComponent:MIGRATION_ID] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            DDLogError(@"%@ Cannot create %@: %@", LOG_TAG, [_migrationDirectory URLByAppendingPathComponent:MIGRATION_ID], error.localizedFailureReason);
            _receiveErrorCount++;
        }
        dispatch_async(self.executorQueue, ^{
            [self scanRootDirectory];
        });
    }
    
    return self;
}

- (int64_t)newRequestId {
    
    int64_t result = [TLTwinlife newRequestId] + self.offsetRequestId;
    return result;
}

- (BOOL)canTerminate {
    @synchronized (self) {
        return self.state == TLAccountMigrationStateTerminate || (self.state == TLAccountMigrationStateWaitAccount && self.accountSent && self.accountReceived);
    }
}

- (void)stopWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ stopWithTerminateReason:%d state: %ld", LOG_TAG, terminateReason, self.state);
    
    @synchronized (self) {
        BOOL commit = terminateReason != TLPeerConnectionServiceTerminateReasonCancel && self.state == TLAccountMigrationStateTerminated;
        
        if (commit) {
            [self.accountMigrationService commitConfigurationWithRootDirectory:self.rootDirectory.path];
            [self.twinlife prepareForRestart];

            // Install a new background observer to trigger an exit as soon as the application goes in background.
            self.twinlife.jobService.backgroundJobObserver = self;
        }
        
        self.state = TLAccountMigrationStateStopped;
        [self finish];
        [self cleanup];
    }
}

- (void) cleanup {
    DDLogVerbose(@"%@ cleanup", LOG_TAG);
    
    @synchronized (self) {
        // Cleanup so that we can restart the account migration after a P2P network interruption.
        [self.listFiles removeAllObjects];
        [self.waitListFiles removeAllObjects];
        [self.sendingFiles removeAllObjects];
        [self.receivingFiles removeAllObjects];
        [self.waitAckFiles removeAllObjects];
        [self.pendingIQRequests removeAllObjects];
        
        self.needRestart = YES;
        
        // Cancel the request timeout if it is running.
        if (self.requestTimeout) {
            [self.requestTimeout cancel];
            self.requestTimeout = nil;
        }
        
        // Cancel receiving files.
        [self.receivingStreams enumerateKeysAndObjectsUsingBlock:^(NSNumber * key, TLReceivingFileInfo * receivingFileInfo, BOOL *stop) {
            [receivingFileInfo cancel];
        }];
    
        [self.receivingStreams removeAllObjects];
        
        // Cancel sending file (there is only one at a time).
        if (self.sendingFile) {
            [self.sendingFile cancel];
            self.sendingFile = nil;
        }
    }
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);
    
    self.state = TLAccountMigrationStateCanceled;
    
    [self.accountMigrationService cancelMigrationWithRootDirectory:self.rootDirectory.path databaseDirectory:[self.databaseFile URLByDeletingLastPathComponent].path];
    [self stopWithTerminateReason:TLPeerConnectionServiceTerminateReasonCancel];
}

- (void)setState:(TLAccountMigrationState)state {
    DDLogVerbose(@"%@ setState state:%ld", LOG_TAG, state);
    
    @synchronized (self) {
        if (state == TLAccountMigrationStateTerminated) {
            BOOL result = [self.fileManager createFileAtPath:[self.rootDirectory URLByAppendingPathComponent:MIGRATION_DONE].path contents:nil attributes:nil];
            
            if (!result) {
                DDLogError(@"%@ Cannot create migration stamp file", LOG_TAG);
            }
        }
        
        if (_state != state) {
            _state = state;
            self.lastReport = [[NSDate date] timeIntervalSince1970] * 1000.0;
            [self updateProgress];
        }
    }
}

- (BOOL)isConnected {
    return self.peerConnectionId != nil;
}

- (void)updateProgress {
    DDLogVerbose(@"%@ updateProgress state:%ld", LOG_TAG, (long)self.state);
    
    int64_t sent = self.sent + self.sendPending;
    int64_t received = self.received + self.receivePending;
    
    TLAccountMigrationStatus *status = [[TLAccountMigrationStatus alloc] initWithState:self.state isConnected:self.isConnected bytesSent:sent estimatedBytesRemainSend:self.sendTotal - sent bytesReceived:received estimatedBytesRemainReceive:self.receiveTotal - received receiveErrorCount:self.receiveErrorCount sendErrorCount:self.sendErrorCount errorCode:self.currentError];
        
    [self.accountMigrationService setProgressWithAccountMigrationId:self.accountMigrationId status:status];
}

#pragma mark - TLBackgroundJobObserver

- (void)onEnterBackground {
    DDLogVerbose(@"%@ onEnterBackground", LOG_TAG);

    /// Called when the application goes in background after the migration succeeded: schedule an exit(0) in 0.1 seconds.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, EXIT_AFTER_SHUTDOWN_DELAY * NSEC_PER_MSEC), self.executorQueue, ^{
        DDLogError(@"%@ stopping after account migration", LOG_TAG);
        exit(0);
    });
}

#pragma mark - TLPeerConnectionHandler

- (void)onDataChannelOpen {
    DDLogVerbose(@"%@ onDataChannelOpen", LOG_TAG);

    @synchronized (self) {
        TLAccountMigrationState state = self.state;
        if (state == TLAccountMigrationStateStarting) {
            self.state = TLAccountMigrationStateNegociate;
        } else if (self.needRestart && state != TLAccountMigrationStateCanceled && state != TLAccountMigrationStateTerminated && state != TLAccountMigrationStateError && state != TLAccountMigrationStateNegociate) {
            self.needRestart = NO;
            self.sent = 0;
            self.received = 0;
            self.sendPending = 0;
            self.receivePending = 0;
            if (self.peerInfo) {
                self.receiveTotal = self.peerInfo.databaseFileSize;
            } else {
                self.receiveTotal = 0;
            }
            if (self.localInfo) {
                self.sendTotal = self.localInfo.databaseFileSize;
            } else {
                self.sendTotal = 0;
            }
            self.state = TLAccountMigrationStateListFiles;
        } else {
            [self updateProgress];
        }
    }
    dispatch_async(self.executorQueue, ^{
        [self processMigration];
    });
}

- (void)onTerminateWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason{
    DDLogVerbose(@"%@ onTerminateWithTerminateReason:%d", LOG_TAG, terminateReason);
    
    @synchronized (self) {
        
        // Record some fatal P2P errors to inform the UI (before calling updateProcess).
        if (terminateReason == TLPeerConnectionServiceTerminateReasonRevoked) {
            self.currentError = TLAccountMigrationErrorCodeRevoked;
        } else if (terminateReason == TLPeerConnectionServiceTerminateReasonNotAuthorized) {
            self.currentError = TLAccountMigrationErrorCodeBadPeerVersion;
        }
        [self updateProgress];
        
        TLAccountMigrationState state = self.state;
        
        if (state == TLAccountMigrationStateTerminated) {
            [self stopWithTerminateReason:terminateReason];
        } else if (terminateReason == TLPeerConnectionServiceTerminateReasonRevoked || terminateReason == TLPeerConnectionServiceTerminateReasonDecline || terminateReason == TLPeerConnectionServiceTerminateReasonCancel || terminateReason == TLPeerConnectionServiceTerminateReasonNotAuthorized || state == TLAccountMigrationStateCanceled) {
            [self cancel];
        } else if (state != TLAccountMigrationStateStopped) {
            dispatch_async(self.executorQueue, ^{
                [self cleanup];
            });
            dispatch_async(self.executorQueue, ^{
                [self scanRootDirectory];
            });
        }
    }
}

- (void) onTimeout {
    DDLogVerbose(@"%@ onTimeout", LOG_TAG);

    [self updateProgress];
}

/// Query the peer device to obtain statistics about the files it provides.
- (void) queryStatsWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize {
    DDLogVerbose(@"%@ queryStatsWithRequestId:%lld maxFileSize:%lld", LOG_TAG, requestId, maxFileSize);

    TLQueryStatsIQ *iq = [[TLQueryStatsIQ alloc] initWithSerializer:IQ_QUERY_STAT_SERIALIZER requestId:requestId maxFileSize:maxFileSize];
    
    [self sendMessageWithIQ:iq statType:IQ_STAT_QUERY];
}

/// Start the migration by asking the peer device to send its files.
- (void) startMigrationWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize {
    DDLogVerbose(@"%@ startMigrationWithRequestId:%lld maxFileSize:%lld", LOG_TAG, requestId, maxFileSize);

    if (self.offsetRequestId == 0) {
        self.offsetRequestId = REQUEST_ID_OFFSET_INITIATOR;
    }

    TLBinaryPacketIQ *startIQ = [self sendStartWithRequestId:requestId maxFileSize:maxFileSize];
    
    if ([startIQ isKindOfClass:TLMigrationErrorIQ.class]) {
        [self sendMessageWithIQ:startIQ statType:IQ_STAT_ERROR];
        self.state = TLAccountMigrationStateError;
        return;
    }
    
    if (self.localInfo) {
        self.sendTotal = self.localInfo.databaseFileSize;
    }
    
    if (self.peerInfo) {
        self.receiveTotal = self.peerInfo.databaseFileSize;
    }
    [self sendMessageWithIQ:startIQ statType:IQ_STAT_START];
}

/// Terminate the migration by sending the termination IQ and closing the P2P connection.
- (void) terminateMigrationWithRequestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done {
    DDLogVerbose(@"%@ terminateMigrationWithRequestId:%lld commit:%@ done:%@", LOG_TAG, requestId , commit? @"YES":@"NO", done? @"YES":@"NO");

    TLTerminateMigrationIQ *iq = [[TLTerminateMigrationIQ alloc] initWithSerializer:IQ_TERMINATE_MIGRATION_SERIALIZER requestId:requestId commit:commit done:done];
    
    [self sendMessageWithIQ:iq statType:IQ_STAT_TERMINATE];
}

/// Shutdown the P2P connection gracefully after the terminate phase1 and phase2.
- (void) shutdownMigrationWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ shutdownMigrationWithRequestId:%lld", LOG_TAG, requestId);
    
    TLShutdownIQ *iq = [[TLShutdownIQ alloc] initWithSerializer:IQ_SHUTDOWN_SERIALIZER requestId:requestId close:NO];

    [self sendMessageWithIQ:iq statType:IQ_STAT_SHUTDOWN];
}

#pragma mark - IQ handlers

/// Request query-stats operation is received.
/// Get the stats about the files to be transferred taking into account a max file size constraint.
- (void)onQueryStatsWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onQueryStatsWithIQ:%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLQueryStatsIQ.class]) {
        DDLogError(@"%@ onQueryStatsWithIQ: Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processQueryStatsWithIQ:(TLQueryStatsIQ *)iq];
    });
}

- (void)onOnQueryStatsWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnQueryStatsWithIQ:%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLOnQueryStatsIQ.class]) {
        DDLogError(@"%@ onOnQueryStatsWithIQ: Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processOnQueryStatsWithIQ:(TLOnQueryStatsIQ *)iq];
    });
}

- (void)onListFilesWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onListFilesWithIQ:%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLListFilesIQ.class]) {
        DDLogError(@"%@ onListFilesWithIQ: Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processListFilesWithIQ:(TLListFilesIQ *)iq];
    });
}

- (void)onOnListFilesWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnListFilesWithIQ:%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLOnListFilesIQ.class]) {
        DDLogError(@"%@ onOnListFilesWithIQ: Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processOnListFilesWithIQ:(TLOnListFilesIQ *)iq];
    });
}

- (void)onStartWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onStartIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLStartIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processStartWithIQ:(TLStartIQ *)iq];
    });
}

- (void)onPutFileWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    
    if (![iq isKindOfClass:[TLPutFileIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processPutFileWithIQ:(TLPutFileIQ *)iq];
    });
}

- (void)onOnPutFileWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnPutFileWithIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnPutFileIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processOnPutFileWithIQ:(TLOnPutFileIQ *)iq];
    });
}

- (void)onSettingsWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSettingsWithIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSettingsIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processSettingsWithIQ:(TLSettingsIQ *)iq];
    });
}

- (void)onSwapAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSwapAccountWithIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLAccountIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processAccountWithIQ:(TLAccountIQ *)iq];
    });
}

- (void)onTerminateMigrationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onTerminateMigrationWithIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLTerminateMigrationIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processTerminateMigrationWithIQ:(TLTerminateMigrationIQ *)iq];
    });
}

- (void)onShutdownWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onShutdownWithIQ iq=%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLShutdownIQ class]]) {
        DDLogError(@"%@ Invalid IQ: %@", LOG_TAG, iq);
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        [self processShutdownWithIQ:(TLShutdownIQ *)iq];
    });
}

- (void)onErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogError(@"%@ onErrorWithIQ iq=%@", LOG_TAG, iq);
    
    dispatch_async(self.executorQueue, ^{
        [self processErrorWithIQ:(TLMigrationErrorIQ *)iq];
    });
}

#pragma mark - process IQs

- (void)processQueryStatsWithIQ:(nonnull TLQueryStatsIQ *)iq {
    DDLogVerbose(@"%@ processQueryStatsWithIQ: %@", LOG_TAG, iq);
    
    int64_t fileCount = 0;
    int64_t maxFileSize = 0;
    int64_t totalFileSize = 0;
    
    NSMutableSet<NSString *> *directories = [[NSMutableSet alloc] init];
    
    self.maxFileSize = iq.maxFileSize;
    
    for (TLFileInfo *fileInfo in self.listFiles) {
        int64_t size = fileInfo.size;
        if (size <= self.maxFileSize) {
            NSString *dir = fileInfo.path;
            NSRange range = [dir rangeOfString:@"/" options:NSBackwardsSearch];
            if (range.length > 0) {
                dir = [dir substringFromIndex:range.location];
            }
            [directories addObject:dir];
            
            fileCount++;
            totalFileSize += size;
            if (maxFileSize < size) {
                maxFileSize = size;
            }
        }
    }
    
    int64_t directoryCount = directories.count;
    
    NSError *error = nil;
    NSDictionary *results = [self.databaseFile resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLFileSizeKey] error:&error];
    if (!results) {
        DDLogError(@"%@ Error retrieving resource keys for DB file (%@): %@\n%@", LOG_TAG, self.databaseFile.path, [error localizedDescription], [error userInfo]);
        return;
    }
    
    NSNumber *databaseFileSize = results[NSURLFileSizeKey];
    NSNumber *dbSpaceAvailable = results[NSURLVolumeAvailableCapacityForImportantUsageKey];
    
    results = [self.databaseFile resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLFileSizeKey] error:&error];
    
    if (!results) {
        DDLogError(@"%@ Error retrieving resource keys for migration directory (%@): %@\n%@", LOG_TAG, self.databaseFile.path, error.localizedDescription, error.userInfo);
        return;
    }
    
    NSNumber *fileSpaceAvailable = results[NSURLVolumeAvailableCapacityForImportantUsageKey];
    
    self.localInfo = [[TLQueryInfo alloc] initWithDirectoryCount:directoryCount fileCount:fileCount maxFileSize:maxFileSize totalFileSize:totalFileSize databaseFileSize:databaseFileSize.longLongValue localFileAvailableSize:dbSpaceAvailable.longLongValue localDatabaseAvailableSize:fileSpaceAvailable.longLongValue];
    
    TLOnQueryStatsIQ *response = [[TLOnQueryStatsIQ alloc] initWithSerializer:IQ_ON_QUERY_STAT_SERIALIZER iq:iq queryInfo:self.localInfo];
    
    [self sendMessageWithIQ:response statType:IQ_STAT_ON_QUERY];
    
    // Setup the local information and propagate to the onQueryStats delegate if necessary (only if we have the peer info).
    // This is not one of our request so use the DEFAULT_REQUEST_ID.
    if (!self.peerInfo){
        [self queryStatsWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] maxFileSize:self.maxFileSize];
    } else {
        [self.accountMigrationService onQueryStatsWithRequestId:TLBaseService.DEFAULT_REQUEST_ID peerInfo:self.peerInfo localInfo:self.localInfo];
    }
}

- (void)processOnQueryStatsWithIQ:(nonnull TLOnQueryStatsIQ *)iq {
    DDLogVerbose(@"%@ processOnQueryStatsWithIQ: %@", LOG_TAG, iq);
    
    self.peerInfo = iq.queryInfo;

    [self.accountMigrationService onQueryStatsWithRequestId:iq.requestId peerInfo:iq.queryInfo localInfo:self.localInfo];
}

- (void) processStartWithIQ:(nonnull TLStartIQ *)iq {
    DDLogVerbose(@"%@ processStartWithIQ: %@", LOG_TAG, iq);
    
    if (iq.maxFileSize < 0) {
        self.state = TLAccountMigrationStateError;
        return;
    }
    
    if (self.offsetRequestId == 0) {
        self.offsetRequestId = REQUEST_ID_OFFSET_CLIENT;
    }

    // Check that we have enough space to receive the files.
    if (self.state == TLAccountMigrationStateNegociate) {
        TLBinaryPacketIQ *resultIQ = [self sendStartWithRequestId:iq.requestId maxFileSize:iq.maxFileSize];
        
        if ([resultIQ isKindOfClass:TLMigrationErrorIQ.class]){
            [self sendMessageWithIQ:resultIQ statType:IQ_STAT_ERROR];
            self.state = TLAccountMigrationStateError;
            return;
        }
        
        [self sendMessageWithIQ:resultIQ statType:IQ_STAT_START];
    }
    
    if (self.peerInfo) {
        self.receiveTotal = self.peerInfo.databaseFileSize;
    }
    if (self.localInfo) {
        self.sendTotal = self.localInfo.databaseFileSize;
    }
    
    self.state = TLAccountMigrationStateListFiles;
    self.maxFileSize = iq.maxFileSize;
    
    [self processMigration];
}

- (void) processListFilesWithIQ:(nonnull TLListFilesIQ *)iq {
    DDLogVerbose(@"%@ processListFilesWithIQ: %@", LOG_TAG, iq);

    self.requestTimeoutExpired = NO;
    
    if (self.state == TLAccountMigrationStateNegociate) {
        self.state = TLAccountMigrationStateListFiles;
    }
    
    NSMutableArray<TLFileState *> *result = [[NSMutableArray alloc] init];
    NSArray<TLFileInfo *> *list = iq.files;
    
    for (TLFileInfo *fileInfo in list) {
        NSString *filePath = [self toLocalPath:fileInfo];
        int64_t offset;
        if (![self.fileManager fileExistsAtPath:filePath]) {
            offset = 0;
        } else {
            NSDictionary *fileAttrs = [self.fileManager attributesOfItemAtPath:filePath error:nil];
            if (!fileAttrs) {
                offset = 0;
            } else {
                int64_t actualSize = ((NSNumber *)fileAttrs[NSFileSize]).longLongValue;
                NSDate *actualModificationDate = (NSDate *)fileAttrs[NSFileModificationDate];

                // Compare size and date but only on the seconds basis (drop the milliseconds because
                // on some OS such as Android, the milliseconds are dropped).
                if (actualSize == fileInfo.size && (!actualModificationDate || (long)([actualModificationDate timeIntervalSince1970]) != (fileInfo.date / 1000L))) {
                    offset = 0;
                    DDLogWarn(@"%@ File %@ was modified", LOG_TAG, fileInfo.path);
                } else {
                    offset = actualSize;
                }
            }
        }
        
        self.receivingFiles[fileInfo.index] = fileInfo;
        
        if (fileInfo.fileId >= FIRST_FILE_INDEX) {
            self.receiveTotal += fileInfo.size;
        }
        
        TLFileState *state = [[TLFileState alloc] initWithFileId:fileInfo.fileId offset:offset];
        [result addObject:state];
    }
    
    TLOnListFilesIQ *response = [[TLOnListFilesIQ alloc] initWithSerializer:IQ_ON_LIST_FILES_SERIALIZER iq:iq files:result];
    
    [self sendMessageWithIQ:response statType:IQ_STAT_ON_LIST_FILES];
}

- (void)processOnListFilesWithIQ:(nonnull TLOnListFilesIQ *)iq {
    DDLogVerbose(@"%@ processOnListFilesWithIQ: %@", LOG_TAG, iq);
    
    self.requestTimeoutExpired = NO;
    [self.pendingIQRequests removeObject:[[NSNumber alloc] initWithLongLong:iq.requestId]];
    
    for (TLFileState *state in iq.files) {
        TLFileInfo *fileInfo = self.waitListFiles[state.index];
        [self.waitListFiles removeObjectForKey:state.index];
        
        if (fileInfo) {
            if (state.offset <= fileInfo.size) {
                fileInfo.remoteOffset = state.offset;
            } else {
                fileInfo.remoteOffset = 0;
            }
            self.sendTotal += fileInfo.size;
            self.sendingFiles[fileInfo.index] = fileInfo;
        } else {
            DDLogWarn(@"%@ File %d was not found", LOG_TAG, state.fileId);
        }
    }
    
    // Continue the migration process.
    if (self.state != TLAccountMigrationStateStopped) {
        dispatch_async(self.executorQueue, ^{
            [self processMigration];
        });
    }
}

/// Convert the peer relative path to a local absolute path.  We must handle some Android -> iOS transformations to
/// capitalize and change the uuid directories to upper case.
- (nonnull NSString *)toLocalPath:(nonnull TLFileInfo *)fileInfo {
    DDLogVerbose(@"%@ toLocalPath: %@", LOG_TAG, fileInfo);

    if (fileInfo.fileId >= FIRST_FILE_INDEX) {
        // We have to make sure the relative path uses one of the formats:
        // - "Conversations/<UUID-UPPPER>/<basename>.<ext>"
        // - "Pictures/<basename>.<ext>"
        NSArray<NSString *> *pathComponents = [fileInfo.path pathComponents];
        NSString *dir = [self.migrationDirectory.path stringByAppendingPathComponent:[[pathComponents objectAtIndex:0] capitalizedString]];
        if (pathComponents.count == 3) {
            dir = [dir stringByAppendingPathComponent:[[pathComponents objectAtIndex:1] uppercaseString]];
            return [dir stringByAppendingPathComponent:[pathComponents objectAtIndex:2]];
        } else {
            return [dir stringByAppendingPathComponent:[pathComponents objectAtIndex:1]];
        }
    }

    NSURL *dbDir = self.databaseFile.URLByDeletingLastPathComponent;
    NSString *path;
    if (fileInfo.fileId == DATABASE_FILE_INDEX) {
        path = [dbDir URLByAppendingPathComponent:MIGRATION_DATABASE_NAME].path;
        self.migrationDatabasePath = path;
    } else if (fileInfo.fileId == DATABASE_CIPHER_3_FILE_INDEX) {
        path = [dbDir URLByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V3_NAME].path;
        self.migrationDatabasePath = path;
    } else if (fileInfo.fileId == DATABASE_CIPHER_4_FILE_INDEX) {
        path = [dbDir URLByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V4_NAME].path;
        self.migrationDatabasePath = path;
    } else if (fileInfo.fileId == DATABASE_CIPHER_5_FILE_INDEX) {
        path = [dbDir URLByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V5_NAME].path;
        self.migrationDatabasePath = path;
    }
    return path;
}

- (void)processPutFileWithIQ:(nonnull TLPutFileIQ *)iq {
    DDLogVerbose(@"%@ processPutFileWithIQ: %@", LOG_TAG, iq);

    self.requestTimeoutExpired = NO;
    
    NSNumber *fileIndex = [iq fileIndex];
    TLReceivingFileInfo *fileStream = self.receivingStreams[fileIndex];
    if (!fileStream) {
        TLFileInfo *fileInfo = self.receivingFiles[fileIndex];
        if (!fileInfo) {
            DDLogWarn(@"%@ File %d not registered in receiving list", LOG_TAG, iq.fileId);
            self.receiveErrorCount++;
            
            TLOnPutFileIQ *response = [[TLOnPutFileIQ alloc] initWithSerializer:IQ_ON_PUT_FILE_SERIALIZER iq:iq fileId:iq.fileId offset:iq.offset];
            [self sendMessageWithIQ:response statType:IQ_STAT_ON_PUT_FILE];
            return;
        }
        
        NSString *path = [self toLocalPath:fileInfo];
        if (![self.fileManager fileExistsAtPath:path]) {
            NSString *dir = [path stringByDeletingLastPathComponent];
            if (![self.fileManager fileExistsAtPath:dir]) {
                NSError *error;
                if (![self.fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
                    DDLogError(@"%@ cannot create directory %@ error: %@", LOG_TAG, dir, error);
                }
            }
            if (![self.fileManager createFileAtPath:path contents:nil attributes:nil]) {
                DDLogError(@"%@ cannot create file %@", LOG_TAG, path);
            }
        }

        DDLogInfo(@"%@ receiving file: %@", LOG_TAG, path);
        fileStream = [[TLReceivingFileInfo alloc] initWithPath:path fileInfo:fileInfo];
        if (![fileStream isOpened]) {
            DDLogError(@"%@ Fatal IO error for %d", LOG_TAG, iq.fileId);
            [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeIoError] statType:IQ_STAT_ERROR];
            self.receiveErrorCount++;
            TLOnPutFileIQ* response = [[TLOnPutFileIQ alloc] initWithSerializer:IQ_ON_PUT_FILE_SERIALIZER iq:iq fileId:iq.fileId offset:-1];
            [self sendMessageWithIQ:response statType:IQ_STAT_ON_PUT_FILE];
            return;
        }
        if (![fileStream seekToFileOffset:iq.offset]) {
            DDLogError(@"%@ seekToFileOffset failed %d", LOG_TAG, iq.fileId);
        }
        
        self.receivingStreams[fileInfo.index] = fileStream;
        self.receivePending += fileStream.position;
    }

    int64_t offset;
        
    @try {
        offset = fileStream.position;
        if (iq.offset > offset) {
            // This error occurs when a file transfer is interrupted and a miss-match occurs due to some IQs that are not taken into account and must be discarded.
            [self.receivingStreams removeObjectForKey:fileIndex];
            [fileStream cancel];
        } else if (iq.offset == offset) {
            if (iq.size > 0) {
                self.receivePending -= offset;
                offset = [fileStream writeChunkWithData:iq.fileData];
                self.receivePending += offset;
            }
                
            if (iq.sha256) {
                [self.receivingStreams removeObjectForKey:fileIndex];
                self.receivePending -= offset;

                if (![fileStream close:iq.sha256]) {
                    offset = 0;
                    DDLogError(@"%@ Bad receipt for %@", LOG_TAG, fileIndex);

                } else {
                    [self.receivingFiles removeObjectForKey:fileIndex];
                    self.received += offset;
                }
            }
                
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000.0;
            if (self.lastReport + 500 < now) {
                self.lastReport = now;
                [self updateProgress];
            }
        }
    } @catch (NSException *exception) {
        if (exception.name == NSFileHandleOperationException) {
            DDLogError(@"%@ Fatal IO error for %d: %@", LOG_TAG, iq.fileId, exception);
            offset = -1; // IO error means we cannot retry.
            self.receiveErrorCount++;

            [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeIoError] statType:IQ_STAT_ERROR];
        } else {
            DDLogError(@"%@ Error error for %d: %@", LOG_TAG, iq.fileId, exception);
            offset = 0; // We could retry
        }
    }
    
    TLOnPutFileIQ* response = [[TLOnPutFileIQ alloc] initWithSerializer:IQ_ON_PUT_FILE_SERIALIZER iq:iq fileId:iq.fileId offset:offset];
    [self sendMessageWithIQ:response statType:IQ_STAT_ON_PUT_FILE];
}

- (void) processOnPutFileWithIQ:(nonnull TLOnPutFileIQ *)iq {
    DDLogVerbose(@"%@ processOnPutFileWithIQ: %@", LOG_TAG, iq);
    
    NSNumber *fileId = [[NSNumber alloc] initWithInt:iq.fileId];
    [self.pendingIQRequests removeObject:[[NSNumber alloc] initWithLongLong:iq.requestId]];
    self.requestTimeoutExpired = NO;

    TLFileInfo *fileInfo = self.waitAckFiles[fileId];
    
    if (fileInfo) {
        // File was received completely and the integrity was verified.
        if (fileInfo.size == iq.offset) {
            [self.waitAckFiles removeObjectForKey:fileId];
            self.sent += fileInfo.size;
            self.sendPending -= fileInfo.size;
            if (self.sendPending < 0) {
                self.sendPending = 0;
            }
        } else if (iq.offset < 0) {
            [self.waitAckFiles removeObjectForKey:fileId];
            self.sendErrorCount++;
            DDLogError(@"%@ IO Error on the peer for file %d", LOG_TAG, iq.fileId);
        } else if (iq.offset == 0 || iq.offset > fileInfo.size || (self.sendingFile && ![self.sendingFile isAcceptedDataChunkWithFileInfo:fileInfo offset:iq.offset queueSize:MAX_PENDING_REQUESTS*DATA_CHUNK_SIZE])) {
            [self.waitAckFiles removeObjectForKey:fileId];
            self.sendingFiles[fileInfo.index] = fileInfo;
            fileInfo.remoteOffset = iq.offset;
            if (self.sendPending < 0) {
                self.sendPending = 0;
            }
            
            if (self.sendingFile && self.sendingFile.fileIndex == fileInfo.fileId) {
                [self.sendingFile cancel];
                self.sendingFile = nil;
            }
            // If we are sending this file, stop immediately so that we restart at new position.
            DDLogError(@"%@ Bad file must resend %@ iq.offset=%ld size=%ld", LOG_TAG, fileInfo.index, iq.offset, fileInfo.size);
        } else {
            fileInfo.remoteOffset = iq.offset;
        }
        
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000.0;
        if (self.lastReport + 500 < now) {
            self.lastReport = now;
            [self updateProgress];
        }

        //Continue the migration process
        if (self.state != TLAccountMigrationStateStopped) {
            dispatch_async(self.executorQueue, ^{
                [self processMigration];
            });
        }
    }
}

- (void) processSettingsWithIQ:(nonnull TLSettingsIQ *)iq {
    DDLogVerbose(@"%@ processSettingsWithIQ: %@", LOG_TAG, iq);
        
    self.requestTimeoutExpired = NO;
    
    NSData *packet = [iq serializeWithSerializerFactory:self.serializerFactory];
    NSURL *settingsUrl = [self.migrationDirectory URLByAppendingPathComponent:@"settings.iq"];
    if ([self.fileManager fileExistsAtPath:settingsUrl.path]) {
        [self.fileManager removeItemAtURL:settingsUrl error:nil];
    }
    if (![self.fileManager createFileAtPath:settingsUrl.path contents:packet attributes:nil]) {
        [self.fileManager removeItemAtURL:settingsUrl error:nil];

        [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeIoError] statType:IQ_STAT_ERROR];
        return;
    }
    
    NSNumber *requestId = [[NSNumber alloc] initWithLongLong:iq.requestId];
    
    if ([self.pendingIQRequests containsObject:requestId]) {
        self.settingsSent = YES;
    }
    [self.pendingIQRequests removeObject:requestId];
    
    self.settingsReceived = YES;
    if (!iq.hasPeerSettings) {
        iq = [self sendSettings];
        [self sendMessageWithIQ:iq statType:IQ_STAT_SETTINGS];
    }
    
    // Continue the migration process
    if (self.state != TLAccountMigrationStateStopped) {
        dispatch_async(self.executorQueue, ^{
            [self processMigration];
        });
    }
}

- (void)processAccountWithIQ:(nonnull TLAccountIQ *)iq {
    DDLogVerbose(@"%@ processAccountWithIQ: %@", LOG_TAG, iq);

    self.requestTimeoutExpired = NO;
    
    NSNumber *requestId = [[NSNumber alloc] initWithLongLong:iq.requestId];
    
    BOOL isKnown = [self.pendingIQRequests containsObject:requestId];
    [self.pendingIQRequests removeObject:requestId];
    
    if (isKnown || iq.hasPeerAccount) {
        self.accountSent = YES;
    }
    self.accountReceived = YES;

    // Extract the twinlife secure configuration (we will need it for the database check).
    self.secureConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:self.serializerFactory content:iq.securedConfiguration];
    if (!self.secureConfiguration) {
        [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeSecureStoreError] statType:IQ_STAT_ERROR];
        return;
    }
    
    if (![TLKeyChain updateKeyChainWithKey:[MIGRATION_PREFIX stringByAppendingString:TWINLIFE_SECURED_CONFIGURATION_KEY] tag:nil data:iq.securedConfiguration alternateApplication:NO]) {
        DDLogError(@"%@ cannot store secure configuration", LOG_TAG);
        [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeSecureStoreError] statType:IQ_STAT_ERROR];
        return;
    }
    if (![TLKeyChain updateKeyChainWithKey:[MIGRATION_PREFIX stringByAppendingString:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY] tag:nil data:iq.accountConfiguration alternateApplication:NO]) {
        DDLogError(@"%@ cannot store account configuration", LOG_TAG);
        [self sendMessageWithIQ:[self sendErrorWithRequestId:iq.requestId errorCode:TLAccountMigrationErrorCodeSecureStoreError] statType:IQ_STAT_ERROR];
        return;
    }
    
    if (!isKnown && self.state == TLAccountMigrationStateWaitAccount) {
        TLAccountIQ *response = [self sendAccountWithRequestId:iq.requestId];
        
        if (response) {
            [self sendMessageWithIQ:response statType:IQ_STAT_ACCOUNT];
        }
    }
    
    // Continue the migration process if we have successfully sent our account and we received the peer account.
    if (self.state == TLAccountMigrationStateWaitAccount && self.accountSent && self.accountReceived) {
        self.state = TLAccountMigrationStateCheckDatabase;
        [self processCheckDatabase];
    }
    
    if (self.state != TLAccountMigrationStateStopped) {
        dispatch_async(self.executorQueue, ^{
            [self processMigration];
        });
    }
}

- (void) processTerminateMigrationWithIQ:(nonnull TLTerminateMigrationIQ *)iq {
    DDLogVerbose(@"%@ processTerminateMigrationWithIQ: %@", LOG_TAG, iq);
    
    // Migration is canceled: cleanup and close the P2P connection.
    if (!iq.commit) {
        [self cancel];
        return;
    }

    // We can accept the terminate-migration IQ only when we reached the WAIT_TERMINATE phase
    // (we have received all files, database, settings, account and the peer also received all this information).
    if (!self.canTerminate) {
        DDLogError(@"%@ onTerminateMigrationIQ received while in state %ld", LOG_TAG,  self.state);
        return;
    }

    // The terminate phase is handled by an upper service that must delete the migration twincode.
    [self.accountMigrationService onTerminateMigrationWithRequestId:iq.requestId deviceMigrationId:self.accountMigrationId commit:YES done:iq.done];
}

- (void) processShutdownWithIQ:(nonnull TLShutdownIQ *)iq {
    DDLogVerbose(@"%@ processShutdownWithIQ: %@", LOG_TAG, iq);

    if (!iq.close) {
        TLShutdownIQ *response = [[TLShutdownIQ alloc] initWithSerializer:IQ_SHUTDOWN_SERIALIZER requestId:iq.requestId close:YES];
        [self sendMessageWithIQ:response statType:IQ_STAT_SHUTDOWN];
    }
    
    // Invalidate the push variant and push notification token otherwise the server can wakeup the other device after we switched.
    [self.managementService setPushNotificationWithVariant:@"" token:@""];
    self.state = TLAccountMigrationStateTerminated;
    
    if (iq.close) {
        [self closeConnection];
    }
}

- (void) processErrorWithIQ:(nonnull TLMigrationErrorIQ *)iq {
    DDLogVerbose(@"%@ processErrorWithIQ: %@", LOG_TAG, iq);

    self.state = TLAccountMigrationStateError;
}

// Migrate the Android SQLCipher database to the iOS to use cipher_plaintext_header_size=32
// A new database key must be set using the hexadecimal format: it contains the encryption key
// followed by the 16-bytes salt.
// See also tryMigrateCipher3WithPath in TLTwinlifeImpl.m
- (BOOL)tryMigrateCipher4WithPath:(nonnull NSString *)path newPath:(nonnull NSString *)newPath key:(nonnull NSString *)key newKey:(nonnull NSString *)newKey {
    DDLogInfo(@"%@ tryMigrateCipher4WithPath: %@ newPath: %@ newKey: %@", LOG_TAG, path, newPath, newKey);

    sqlite3 *database;
    if (sqlite3_open([path UTF8String], &database) != SQLITE_OK) {
        return NO;
    }

    NSData *keyData = [NSData dataWithBytes:[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
    int rc = sqlite3_key(database, [keyData bytes], (int)[keyData length]);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    sqlite3_stmt *stmt;
    rc = sqlite3_prepare_v2(database, "pragma user_version", -1, &stmt, 0);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }
    rc = sqlite3_step(stmt);
    if (rc != SQLITE_ROW) {
        sqlite3_close(database);
        return NO;
    }
    int version = sqlite3_column_int(stmt, 0);
    sqlite3_finalize(stmt);

    // Keep 32 bytes header in clear text for iOS for Apple's stupidities.
    rc = sqlite3_exec(database, "PRAGMA cipher_plaintext_header_size = 32", NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_exec(database, [[NSString stringWithFormat:@"ATTACH DATABASE '%@' AS encrypted KEY \"x'%@'\";", newPath, newKey] UTF8String], NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_exec(database, "SELECT sqlcipher_export('encrypted');", NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_exec(database, [[NSString stringWithFormat:@"PRAGMA encrypted.user_version = %d", version] UTF8String], NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_exec(database, "DETACH DATABASE 'encrypted';", NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_close(database);

    return rc == SQLITE_OK ? YES : NO;
}

- (void)processCheckDatabase {
    DDLogVerbose(@"%@ processCheckDatabase", LOG_TAG);

    if (!self.secureConfiguration || !self.migrationDatabasePath) {
        DDLogError(@"%@ no secure configuration to check the database", LOG_TAG);
        [self sendMessageWithIQ:[self sendErrorWithRequestId:[self newRequestId] errorCode:TLAccountMigrationErrorCodeInternalError] statType:IQ_STAT_ERROR];
        self.state = TLAccountMigrationStateError;
        return;
    }

    int cipherVersion = 4;
    NSString *databaseKey = self.secureConfiguration.databaseKey;

    if (databaseKey.length < 96) {
        NSString *newKey = [TLTwinlifeSecuredConfiguration generateDatabaseKey];
        NSString *newPath = [self.databaseFile.URLByDeletingLastPathComponent URLByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V5_NAME].path;
        [self.fileManager removeItemAtPath:newPath error:nil];

        if (![self tryMigrateCipher4WithPath:self.migrationDatabasePath newPath:newPath key:databaseKey newKey:newKey]) {
            DDLogError(@"%@ cannot migrate database to iOS format", LOG_TAG);
            [self sendMessageWithIQ:[self sendErrorWithRequestId:[self newRequestId] errorCode:TLAccountMigrationErrorCodeBadDatabase] statType:IQ_STAT_ERROR];
            self.state = TLAccountMigrationStateError;
            return;
        }
        [self.fileManager removeItemAtPath:self.migrationDatabasePath error:nil];
        self.migrationDatabasePath = newPath;
        databaseKey = newKey;

        NSData *data = [self.secureConfiguration exportWithKey:newKey];
        if (![TLKeyChain updateKeyChainWithKey:[MIGRATION_PREFIX stringByAppendingString:TWINLIFE_SECURED_CONFIGURATION_KEY] tag:nil data:data alternateApplication:NO]) {
            DDLogError(@"%@ cannot update secure configuration", LOG_TAG);
            [self sendMessageWithIQ:[self sendErrorWithRequestId:[self newRequestId] errorCode:TLAccountMigrationErrorCodeSecureStoreError] statType:IQ_STAT_ERROR];
            return;
        }
        self.secureConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:self.serializerFactory content:data];
    }

    FMDatabaseQueue *databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.migrationDatabasePath];
    DDLogVerbose(@"%@ Database key: %@", LOG_TAG, databaseKey);

    // Check database and its key to make sure we can open it.
    __block NSError *error = nil;
    [databaseQueue inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet;
        if (cipherVersion == 3) {
            [database setKey:databaseKey];
            [database executeUpdate:@"PRAGMA cipher_compatibility = 3"];
            resultSet = [database executeQuery:@"SELECT COUNT(*) FROM sqlite_master" values:nil error:&error];

        } else {
            // Keep 32 bytes header in clear text for iOS for Apple's stupidities.
            [database executeUpdate:@"PRAGMA cipher_plaintext_header_size = 32"];
            int result = [database intForQuery:[NSString stringWithFormat:@"PRAGMA key = \"x'%@'\";", databaseKey]];
            if (result != 0) {
                DDLogWarn(@"%@ PRAGMA key returned %d", LOG_TAG, result);
            }
            resultSet = [database executeQuery:@"SELECT COUNT(*) FROM sqlite_master" values:nil error:&error];
        }
        [resultSet close];
    }];
    [databaseQueue close];

    DDLogError(@"%@ check database result: %@", LOG_TAG, error);

    if (error) {
        [self sendMessageWithIQ:[self sendErrorWithRequestId:[self newRequestId] errorCode:TLAccountMigrationErrorCodeBadDatabase] statType:IQ_STAT_ERROR];
        self.state = TLAccountMigrationStateError;
        return;
    }

    self.state = TLAccountMigrationStateTerminate;
}

- (void)processMigration {
    DDLogInfo(@"%@ processMigration state: %ld pendingSize: %ld", LOG_TAG, self.state, self.pendingIQRequests.count);

    while (self.pendingIQRequests.count < MAX_PENDING_REQUESTS) {
        switch(self.state) {
            case TLAccountMigrationStateListFiles: {
                TLListFilesIQ *listFilesIQ = [self sendListFiles];
                if (listFilesIQ) {
                    [self sendIQRequestWithIQ:listFilesIQ statType:IQ_STAT_LIST_FILES];
                } else {
                    self.state = TLAccountMigrationStateSendFiles;
                }
                break;
            }
            case TLAccountMigrationStateSendFiles: {
                TLPutFileIQ *putFileIQ = [self sendFileChunk];
                if (putFileIQ) {
                    [self sendIQRequestWithIQ:putFileIQ statType:IQ_STAT_PUT_FILE];
                } else if (self.waitListFiles.count > 0 || self.sendingFiles.count > 0 || self.waitAckFiles.count > 0) {
                    // We still have files to send/receive.
                    return;
                } else {
                    self.state = TLAccountMigrationStateSendSettings;
                }
                break;
            }
            case TLAccountMigrationStateSendSettings: {
                TLSettingsIQ *settingsIQ = [self sendSettings];
                [self sendIQRequestWithIQ:settingsIQ statType:IQ_STAT_SETTINGS];
                
                self.state = TLAccountMigrationStateSendDatabase;

                // Force another database sync to flush the WAL file before sending the database file in the next step.
                [self.databaseService syncDatabase];

                NSDictionary *dbAttrs = [self.fileManager attributesOfItemAtPath:self.databaseFile.path error:nil];
                int64_t dbSize = ((NSNumber *)dbAttrs[NSFileSize]).longLongValue;
                NSDate *dbDate = (NSDate *)dbAttrs[NSFileModificationDate];
                
                TLFileInfo *fileInfo = [[TLFileInfo alloc] initWithFileId:self.databaseFileIndex path:@"fake.db" size:dbSize date:[dbDate timeIntervalSince1970] * 1000];
                [self.listFiles addObject:fileInfo];
                
                TLListFilesIQ *listFilesIQ = [self sendListFiles];
                if (listFilesIQ) {
                    [self sendIQRequestWithIQ:listFilesIQ statType:IQ_STAT_LIST_FILES];
                }
                break;
            }
            case TLAccountMigrationStateSendDatabase: {
                TLPutFileIQ *putFileIQ = [self sendFileChunk];
                
                if(putFileIQ) {
                    [self sendIQRequestWithIQ:putFileIQ statType:IQ_STAT_PUT_FILE];
                } else {
                    self.state = TLAccountMigrationStateWaitFiles;
                }
                break;
            }
            case TLAccountMigrationStateWaitFiles: {
                if (self.waitListFiles.count > 0) {
                    return;
                }
                if (self.sendingFiles.count > 0) {
                    self.state = TLAccountMigrationStateSendDatabase;
                } else if (self.waitAckFiles.count > 0 || self.receivingFiles.count > 0) {
                    // DB transfer still in progress
                    return;
                } else {
                    self.state = TLAccountMigrationStateSendAccount;
                }
                break;
            }
            case TLAccountMigrationStateSendAccount: {
                TLAccountIQ *accountIQ = [self sendAccountWithRequestId:[self newRequestId]];
                if (accountIQ) {
                    [self sendIQRequestWithIQ:accountIQ statType:IQ_STAT_ACCOUNT];
                    self.state = TLAccountMigrationStateWaitAccount;
                } else {
                    DDLogError(@"%@ sendAccount failed", LOG_TAG);
                }
                return;
            }
            case TLAccountMigrationStateCheckDatabase: {
                return;
            }
            case TLAccountMigrationStateTerminate: {
                return;
            }
            default:
                return;
        }
    }
}

#pragma mark - send IQs

- (void) sendIQRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ sendIQRequestWithIQ: %@ statType: %d", LOG_TAG, iq, statType);

    NSNumber *requestId = [[NSNumber alloc] initWithLongLong:iq.requestId];
    [self.pendingIQRequests addObject:requestId];
    
    if (!self.requestTimeout) {
        self.requestTimeout = [[self.twinlife getJobService] scheduleWithJob:self delay:REQUEST_TIMEOUT priority:TLJobPriorityMessage];
    }
    self.requestTimeoutExpired = NO;
    
    [self sendMessageWithIQ:iq statType:statType];
}

/// Request activity timeout handler fired to verify we're not stuck waiting for a response

- (void) runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    self.requestTimeout = nil;
    
    if (self.pendingIQRequests.count == 0) {
        self.requestTimeoutExpired = NO;
        return;
    }
    
    if (self.requestTimeoutExpired) {
        DDLogError(@"%@ timeout on pending reauests!", LOG_TAG);
        
        [self closeConnection];
        return;
    }
    
    self.requestTimeoutExpired = YES;
    
    self.requestTimeout = [[self.twinlife getJobService] scheduleWithJob:self delay:REQUEST_TIMEOUT priority:TLJobPriorityMessage];
}

- (nonnull TLBinaryPacketIQ *)sendStartWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize {
    DDLogVerbose(@"%@ sendStartWithRequestId: %lld maxFileSize: %lld", LOG_TAG, requestId, maxFileSize);
    
    if (!self.peerInfo) {
        return [self sendErrorWithRequestId:requestId errorCode:TLAccountMigrationErrorCodeInternalError];
    }
    
    int64_t dbFs = self.peerInfo.localDatabaseAvailableSize - self.peerInfo.databaseFileSize;
    int64_t filesFs = self.peerInfo.localFileAvailableSize - self.peerInfo.totalFileSize;
    
    if (filesFs < 0 || dbFs < 0) {
        return [self sendErrorWithRequestId:requestId errorCode:TLAccountMigrationErrorCodeNoSpaceLeft];
    }
    
    return [[TLStartIQ alloc] initWithSerializer:IQ_START_SERIALIZER requestId:requestId maxFileSize:maxFileSize];
}

- (nonnull TLBinaryPacketIQ *)sendErrorWithRequestId:(int64_t)requestId errorCode:(TLAccountMigrationErrorCode)errorCode {
    DDLogVerbose(@"%@ sendErrorWithRequestId: %lld errorCode: %ld", LOG_TAG, requestId, errorCode);

    self.currentError = errorCode;
    
    return [[TLMigrationErrorIQ alloc] initWithSerializer:IQ_ERROR_SERIALIZER requestId:requestId errorCode:errorCode];
}

-(nonnull TLSettingsIQ *)sendSettings {
    DDLogVerbose(@"%@ sendSettings", LOG_TAG);

    NSDictionary<NSUUID *, NSString*> *settings = [TLConfigIdentifier exportConfig];
    return [[TLSettingsIQ alloc] initWithSerializer:IQ_SETTINGS_SERIALIZER requestId:[self newRequestId] hasPeerSettings:self.settingsReceived settings:settings];
}

-(nonnull TLAccountIQ *)sendAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ sendAccountWithRequestId: %lld", LOG_TAG, requestId);

    NSData *secureData = [TLTwinlifeSecuredConfiguration exportWithSerializerFactory:self.serializerFactory];
    NSData *accountData =  [TLAccountServiceSecuredConfiguration exportWithSerializerFactory:self.serializerFactory];
    
    return [[TLAccountIQ alloc] initWithSerializer:IQ_SWAP_ACCOUNT_SERIALIZER requestId:requestId securedConfiguration:secureData accountConfiguration:accountData hasPeerAccount:self.accountReceived];
}

/// Build an IQ to send a list of files.
-(nullable TLListFilesIQ *)sendListFiles {
    DDLogVerbose(@"%@ sendListFiles", LOG_TAG);
    
    long index = self.listFiles.count;
    
    if (index == 0) {
        // No files
        return nil;
    }
    
    NSMutableArray<TLFileInfo *> *list = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < MAX_FILES_PER_IQ && index >= 1;) {
        index--;
        TLFileInfo *fileInfo = [self.listFiles objectAtIndex:index];
        [self.listFiles removeObjectAtIndex:index];
        if (fileInfo.size <= self.maxFileSize) {
            [list addObject:fileInfo];
            self.waitListFiles[fileInfo.index] = fileInfo;
            i++;
        }
    }
    
    [self updateProgress];
    int64_t requestId = [self newRequestId];
    return [[TLListFilesIQ alloc] initWithSerializer:IQ_LIST_FILES_SERIALIZER requestId:requestId files:list];
}

- (nullable TLPutFileIQ *)sendFileChunk {
    DDLogVerbose(@"%@ sendFileChunk", LOG_TAG);

    if (!self.sendingFile) {
        long size = self.sendingFiles.count;
        if (size == 0){
            //No file to send, we are done!
            return nil;
        }
        
        NSNumber *fileIndex = [self.sendingFiles.keyEnumerator nextObject];
        TLFileInfo *sendFile = self.sendingFiles[fileIndex];
        [self.sendingFiles removeObjectForKey:fileIndex];
        self.waitAckFiles[sendFile.index] = sendFile;
        
        NSURL *fileUrl;
        // Unlike Android, we only send the cipher V5 database.
        if (sendFile.fileId == DATABASE_CIPHER_5_FILE_INDEX) {
            fileUrl = self.databaseFile;
        } else {
            fileUrl = [self.rootDirectory URLByAppendingPathComponent:sendFile.path];
        }
        DDLogInfo(@"%@ sending file: %@", LOG_TAG, sendFile.path);

        self.sendingFile = [[TLSendingFileInfo alloc] initWithPath:fileUrl.path fileInfo:sendFile];
        
        if (self.sendingFile.isFinished) {
            int64_t requestId = [self newRequestId];
            
            NSData *sha256 = [self.sendingFile digest];
            self.sendingFile = nil;
            return [[TLPutFileIQ alloc] initWithSerializer:IQ_PUT_FILE_SERIALIZER requestId:requestId fileId:sendFile.fileId dataOffset:0 offset:sendFile.size size:0 fileData:nil sha256:sha256];
        }
    }
    int64_t offset = self.sendingFile.currentPosition;
    NSData *data;
    @try {
        data = [self.sendingFile readChunkWithSize:DATA_CHUNK_SIZE position:offset];
    } @catch (NSException *exception) {
        DDLogError(@"%@ Couldn't read sendingFile %d: %@", LOG_TAG, self.sendingFile.fileIndex, exception);
        return nil;
    }
    
    int size = (int)data.length;
    int fileId = self.sendingFile.fileIndex;
    NSData *sha256 = nil;
    if ([self.sendingFile isFinished] || size == 0) {
        sha256 = [self.sendingFile digest];
        self.sendingFile = nil;
    }
    
    self.sendPending += size;
    
    int64_t requestId = [self newRequestId];
    
    return [[TLPutFileIQ alloc] initWithSerializer:IQ_PUT_FILE_SERIALIZER requestId:requestId fileId:fileId dataOffset:0 offset:offset size:size fileData:data sha256:sha256];
}

- (void)scanRootDirectory {
    DDLogDebug(@"%@ scanRootDirectory", LOG_TAG);
    
    NSString *path = [self.rootDirectory URLByAppendingPathComponent:@"Conversations"].path;
    if ([self.fileManager fileExistsAtPath:path]) {
        [self scanDirectoryWithDirectory:path relativePath:@"Conversations"];
    }
    path = [self.rootDirectory URLByAppendingPathComponent:@"Pictures"].path;
    if ([self.fileManager fileExistsAtPath:path]) {
        [self scanDirectoryWithDirectory:path relativePath:@"Pictures"];
    }
}

/// Scan the directory recursively and identify the files that must be copied.
/// directory: the directory to scan.
/// basePath: the relative base of the directory.
- (void)scanDirectoryWithDirectory:(nonnull NSString *)directory relativePath:(nonnull NSString *)relativePath {
    DDLogVerbose(@"%@ scanDirectoryWithDirectory:%@ relativePath:%@", LOG_TAG, directory, relativePath);

    NSError *error;
    NSArray<NSString *> *list = [self.fileManager contentsOfDirectoryAtPath:directory error:&error];
    
    if (!list) {
        DDLogVerbose(@"%@ could not get content of directory %@: %@", LOG_TAG, directory, error.localizedFailureReason);
        return;
    }
    
    for (NSString *file in list) {
        BOOL isDirectory;
        NSString *absolutePath = [directory stringByAppendingPathComponent:file];
        
        BOOL exists = [self.fileManager fileExistsAtPath:absolutePath isDirectory:&isDirectory];
        
        if (exists) {
            NSString *fileRelativePath = [NSString stringWithFormat:@"%@/%@", relativePath, file];
            if (isDirectory) {
                [self scanDirectoryWithDirectory:absolutePath relativePath:fileRelativePath];
            } else {
                NSDictionary *fileAttrs = [self.fileManager attributesOfItemAtPath:absolutePath error:nil];
                int64_t size = ((NSNumber *)fileAttrs[NSFileSize]).longLongValue;
                NSDate *date = (NSDate *)fileAttrs[NSFileModificationDate];

                self.fileIndex++;
                TLFileInfo *fileInfo = [[TLFileInfo alloc] initWithFileId:self.fileIndex path:fileRelativePath size:size date:[date timeIntervalSince1970] * 1000];
                [self.listFiles addObject:fileInfo];
            }
        }
    }
}

+ (nullable NSDictionary<NSUUID *,NSString *> *) getMigrationSettingsWithMigrationDirectory:(NSURL *)migrationDirectoryURL {
    DDLogVerbose(@"%@ getMigrationSettingsWithMigrationDirectory:%@", LOG_TAG, migrationDirectoryURL.path);
    
    NSError *error;
    
    NSFileHandle *settingsFileHandle = [NSFileHandle fileHandleForReadingFromURL:[migrationDirectoryURL URLByAppendingPathComponent:@"settings.iq"] error:&error];
    
    if (error) {
        DDLogError(@"%@ error opening settings.iq: %@", LOG_TAG, error.localizedFailureReason);
        return nil;
    }
    
    if (!settingsFileHandle) {
        DDLogError(@"%@ settings.iq not found: %@", LOG_TAG, error.localizedFailureReason);
        return nil;
    }
    
    NSData *data = [settingsFileHandle readDataToEndOfFile];
    [settingsFileHandle closeFile];
    //TODOAM: check length?
    
    TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:data];
    
    NSUUID *schemaId = [binaryDecoder readUUID];
    int schemaVersion = [binaryDecoder readInt];
    
    if (![[[NSUUID alloc] initWithUUIDString:SETTINGS_SCHEMA_ID] isEqual:schemaId] || schemaVersion != 1) {
        return nil;
    }
    
    TLSerializerFactory *factory = [[TLSerializerFactory alloc] init];
    
    TLSettingsIQ *iq = (TLSettingsIQ *)[IQ_SETTINGS_SERIALIZER deserializeWithSerializerFactory:factory decoder:binaryDecoder];
    
    return iq.settings;
}

@end

