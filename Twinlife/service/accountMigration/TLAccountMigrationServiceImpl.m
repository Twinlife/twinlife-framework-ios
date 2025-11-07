/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLAccountMigrationServiceImpl.h"
#import "TLAccountMigrationExecutor.h"
#import "TLBaseServiceImpl.h"
#import "TLDatabaseService.h"
#import "TLTwincodeOutboundService.h"
#import "TLManagementService.h"
#import "TLPeerConnectionService.h"
#import "TLTwinlifeImpl.h"
#import "TLKeyChain.h"
#import "TLTwinlifeSecuredConfiguration.h"
#import "TLAccountServiceSecuredConfiguration.h"
#import "TLFileInfo.h"
#import "TLConfigIdentifier.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define ACCOUNT_MIGRATION_SERVICE_VERSION @"2.1.1"

@implementation TLAccountMigrationStatus

- (nonnull instancetype)initWithState:(TLAccountMigrationState)state isConnected:(BOOL)isConnected bytesSent:(int64_t)bytesSent estimatedBytesRemainSend:(int64_t)estimatedBytesRemainSend bytesReceived:(int64_t)bytesReceived estimatedBytesRemainReceive:(int64_t)estimatedBytesRemainReceive receiveErrorCount:(int)receiveErrorCount sendErrorCount:(int)sendErrorCount errorCode:(TLAccountMigrationErrorCode)errorCode {
    
    self = [[TLAccountMigrationStatus alloc] init];
    
    if (self) {
        BOOL isFinished = state == TLAccountMigrationStateTerminate || state == TLAccountMigrationStateTerminated || state == TLAccountMigrationStateStopped;
        
        _state = state;
        _isConnected = isConnected;
        _bytesSent = bytesSent;
        _bytesReceived = bytesReceived;
        _receiveErrorCount = receiveErrorCount;
        _sendErrorCount = sendErrorCount;
        _errorCode = errorCode;
        
        if (estimatedBytesRemainSend <= 0 || isFinished) {
            _estimatedBytesRemainSend = 0;
        } else {
            _estimatedBytesRemainSend = estimatedBytesRemainSend;
        }
        if (estimatedBytesRemainReceive <= 0 || isFinished) {
            _estimatedBytesRemainReceive = 0;
        } else {
            _estimatedBytesRemainReceive = estimatedBytesRemainReceive;
        }
    }
    
    return self;
}

- (double)sendProgress {
    int64_t total = self.bytesSent + self.estimatedBytesRemainSend;
    if (total == 0){
        return 0;
    } else {
        return (self.bytesSent * 100) / (double)total;
    }
}

- (double)receiveProgress {
    int64_t total = self.bytesReceived + self.estimatedBytesRemainReceive;
    if (total == 0){
        return 0;
    } else {
        return (self.bytesReceived * 100) / (double)total;
    }
}

- (double)progress {
    int64_t total = self.bytesReceived + self.estimatedBytesRemainReceive + self.bytesSent + self.estimatedBytesRemainSend;
    if (total == 0){
        return 0;
    } else {
        return ((self.bytesReceived + self.bytesSent) * 100) / (double)total;
    }
}

- (nonnull NSString *)description {

    NSMutableString *description = [[NSMutableString alloc] initWithFormat:@"[state: %ld", self.state];
    if (self.errorCode != TLAccountMigrationErrorCodeNone) {
        [description appendFormat:@", errorCode: %ld", self.errorCode];
    }
    if (self.isConnected) {
        [description appendFormat:@", connected, progress: %f", [self progress]];
    }
    [description appendString:@"]"];
    return description;
}

@end

@interface TLAccountMigrationService ()

@property (nonatomic, nonnull) TLDatabaseService *database;
@property (nonatomic, nonnull) NSString *databasePath;

@end

//
// Implementation: TLAccountMigrationServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountMigrationServiceConfiguration"

@implementation TLAccountMigrationServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdManagementService version:[TLAccountMigrationService VERSION] serviceOn:NO];
    
    return self;
}


@end

@interface TLAccountMigrationService ()

@property (nullable, nonatomic) TLAccountMigrationExecutor *currentAccountMigration;
@property (nonnull, nonatomic, readonly) NSFileManager *fileManager;
@property (nonnull, nonatomic, readonly) TLDatabaseService *databaseService;

@end

@implementation TLAccountMigrationService


+ (nonnull NSString *)VERSION {
    return ACCOUNT_MIGRATION_SERVICE_VERSION;
}

- (nullable NSUUID *)getActiveDeviceMigrationId {
    if (self.activeMigrationId) {
        return self.activeMigrationId;
    }
    
    NSURL *migrationIdURL = [[[TLTwinlife getAppGroupURL:self.fileManager] URLByAppendingPathComponent:MIGRATION_DIR] URLByAppendingPathComponent:MIGRATION_ID];
    
    NSString *migrationId = [[NSString alloc] initWithContentsOfFile:migrationIdURL.path encoding:NSUTF8StringEncoding error:nil];
    
    if (migrationId) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:migrationId];
        
        if (uuid) {
            return uuid;
        }
        
        DDLogVerbose(@"%@ getActiveMigrationId: migration id file %@ exists but its content is invalid: %@", LOG_TAG,  migrationIdURL.path, migrationId);
    }
    
    return nil;
}

/// Start the device migration process by setting up and opening the P2P connection to the peer twincode outboundid.
- (void)outgoingStartMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ outgoingStartMigrationWithRequestId:%lld accountMigrationId:%@ peerTwincodeOutboundId:%@ twincodeOutboundId:%@", LOG_TAG, requestId, accountMigrationId.UUIDString, peerTwincodeOutboundId.UUIDString, twincodeOutboundId.UUIDString);
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeServiceUnavailable errorParameter:nil];
        return;
    }
    
    NSURL* filesDir = [TLTwinlife getAppGroupURL:self.fileManager];
    
    if (!filesDir) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLAccountMigrationExecutor *accountMigration;
    NSString *peerId = [self.twinlife.twincodeOutboundService getPeerId:peerTwincodeOutboundId twincodeOutboundId:twincodeOutboundId];

    // Force a database sync before starting the migration to flush the WAL file
    // (another one will be made before sending the database in case it was changed).
    [self.databaseService syncDatabase];
    @synchronized (self) {
        if (self.currentAccountMigration) {
            accountMigration = nil;
        } else {
            NSURL *dbUrl = [[NSURL alloc] initFileURLWithPath:self.databasePath];
            
            accountMigration = [[TLAccountMigrationExecutor alloc] initWithTwinlife:self.twinlife accountMigrationService:self databaseService:self.databaseService databaseFile:dbUrl accountMigrationId:accountMigrationId peerId:peerId rootDirectory:filesDir];
            self.currentAccountMigration = accountMigration;
            self.activeMigrationId = accountMigrationId;
        }
    }
    
    if (!accountMigration) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    [accountMigration startOutgoingConnection];
}

/// Start the device migration process by accepting the incoming P2P connection from the peer.
- (void)incomingStartMigrationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId accountMigrationId:(nonnull NSUUID *)accountMigrationId peerTwincodeOutboundId:(nullable NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ incomingStartMigrationWithPeerConnectionId:%@ accountMigrationId:%@ peerTwincodeOutboundId:%@ twincodeOutboundId:%@", LOG_TAG, peerConnectionId.UUIDString, accountMigrationId.UUIDString, peerTwincodeOutboundId.UUIDString, twincodeOutboundId.UUIDString);

    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        return;
    }
    
    TLPeerConnectionService *peerConnectionService = self.twinlife.peerConnectionService;
    TLOffer *peerOffer = [peerConnectionService getPeerOfferWithPeerConnectionId:peerConnectionId];
    NSURL* filesDir = [TLTwinlife getAppGroupURL:self.fileManager];
    if (!peerOffer || !peerOffer.data || !filesDir || !peerTwincodeOutboundId) {
        [peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonNotAuthorized];
        return;
    }

    // Force a database sync before starting the migration to flush the WAL file
    // (another one will be made before sending the database in case it was changed).
    [self.databaseService syncDatabase];

    TLAccountMigrationExecutor *accountMigration;
    NSString *peerId = [self.twinlife.twincodeOutboundService getPeerId:peerTwincodeOutboundId twincodeOutboundId:twincodeOutboundId];
    
    @synchronized (self) {
        accountMigration = self.currentAccountMigration;
        if (!accountMigration) {
            NSURL *dbUrl = [[NSURL alloc] initFileURLWithPath:self.databasePath];
            
            accountMigration = [[TLAccountMigrationExecutor alloc] initWithTwinlife:self.twinlife accountMigrationService:self databaseService:self.databaseService databaseFile:dbUrl accountMigrationId:accountMigrationId peerId:peerId rootDirectory:filesDir];
            self.currentAccountMigration = accountMigration;
            self.activeMigrationId = accountMigrationId;
        } else if (![accountMigrationId isEqual:accountMigration.accountMigrationId]){
            accountMigration = nil;
        }
    }
    
    if (!accountMigration) {
        [peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonBusy];
        return;
    }
    
    [accountMigration startIncomingConnectionWithPeerConnectionId:peerConnectionId];
}

- (void)queryStatsWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize {
    DDLogVerbose(@"%@ queryStatsWithRequestId:%lld maxFileSize:%lld ", LOG_TAG, requestId, maxFileSize);

    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeServiceUnavailable errorParameter:nil];
        return;
    }

    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (!accountMigration) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    if (!accountMigration.isConnected) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        return;
    }
    
    [accountMigration queryStatsWithRequestId:requestId maxFileSize:maxFileSize];
}


- (void)startMigrationWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize {
    DDLogVerbose(@"%@ startMigrationWithRequestId:%lld maxFileSize:%lld ", LOG_TAG, requestId, maxFileSize);

    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeServiceUnavailable errorParameter:nil];
        return;
    }

    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (!accountMigration) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    if (!accountMigration.isConnected) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        return;
    }
    
    [accountMigration startMigrationWithRequestId:requestId maxFileSize:maxFileSize];
}

- (void)terminateMigrationWithRequestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done {
    DDLogVerbose(@"%@ terminateMigrationWithRequestId:%lld commit:%@ done:%@", LOG_TAG, requestId, commit ? @"YES":@"NO", done ? @"YES":@"NO");
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeServiceUnavailable errorParameter:nil];
        return;
    }
    
    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (!accountMigration) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    //Migration is canceled: cleanup
    if (!commit) {
        [accountMigration cancel];
    }
    
    if (!accountMigration.isConnected) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        return;
    }
    
    [accountMigration terminateMigrationWithRequestId:requestId commit:commit done:done];
}


- (void)shutdownMigrationWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ shutdownMigrationWithRequestId:%lld", LOG_TAG, requestId);
    
    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeServiceUnavailable errorParameter:nil];
        return;
    }
    
    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (!accountMigration) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    if (accountMigration.state != TLAccountMigrationStateTerminate) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    if (!accountMigration.isConnected) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        return;
    }
    
    // Invalidate the push variant and push notification token otherwise the server
    // can wakeup the other device after we switched.
    [[self.twinlife getManagementService] setPushNotificationWithVariant:@"" token:@""];
    [accountMigration shutdownMigrationWithRequestId:requestId];
}

- (BOOL)cancelMigrationWithDeviceMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ cancelMigrationWithDeviceMigrationId:%@", LOG_TAG, accountMigrationId.UUIDString);

    if (!self.isServiceOn) {
        DDLogError(@"%@ service is not configured, aborting migration", LOG_TAG);
        return NO;
    }

    TLAccountMigrationExecutor *accountMigration;
    
    @synchronized (self) {
        accountMigration = self.currentAccountMigration;
        if (accountMigration) {
            // If this is another account migration object that is deleted/canceled, ignore it.
            if (![accountMigrationId isEqual:accountMigration.accountMigrationId]) {
                return NO;
            }
            
            // If we are in terminate or terminated state, we can receive a cancelMigration() because the peer
            // has deleted the migration object+twincode but this is the normal termination process.
            TLAccountMigrationState state = accountMigration.state;
            if (state == TLAccountMigrationStateTerminate || state == TLAccountMigrationStateTerminated) {
                return NO;
            }
        }
        [self cleanup];
    }
    
    if (accountMigration) {
        [accountMigration cancel];
    }
    
    NSURL *rootDirectory = [TLTwinlife getAppGroupURL:self.fileManager];
    if (rootDirectory) {
        [self cancelMigrationWithRootDirectory:rootDirectory.path databaseDirectory:rootDirectory.path];
    }
    
    return YES;
}

- (void)cancelMigrationWithRootDirectory:(nonnull NSString*)rootDirectory databaseDirectory:(nullable NSString *)databaseDirectory{
    DDLogVerbose(@"%@ cancelMigrationWithRootDirectory:%@ databaseDirectory:%@", LOG_TAG, rootDirectory, databaseDirectory);
    
    [self.fileManager removeItemAtPath:[rootDirectory stringByAppendingPathComponent:MIGRATION_DIR] error:nil];
    
    if (databaseDirectory) {
        [self.fileManager removeItemAtPath:[databaseDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_NAME] error:nil];
        [self.fileManager removeItemAtPath:[databaseDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V3_NAME] error:nil];
        [self.fileManager removeItemAtPath:[databaseDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V4_NAME] error:nil];
        [self.fileManager removeItemAtPath:[databaseDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V5_NAME] error:nil];
    }
    
    [TLKeyChain removeKeyChainWithKey:[MIGRATION_PREFIX stringByAppendingString:TWINLIFE_SECURED_CONFIGURATION_KEY] tag:nil];
    [TLKeyChain removeKeyChainWithKey:[MIGRATION_PREFIX stringByAppendingString:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY] tag:nil];

    [self cleanup];
}

- (void)setProgressWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(nonnull TLAccountMigrationStatus *)status {
    DDLogVerbose(@"%@ setProgressWithAccountMigrationId:%@ status:%@", LOG_TAG, accountMigrationId.UUIDString, status);

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onStatusChangeWithDeviceMigrationId:status:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLAccountMigrationServiceDelegate>)delegate onStatusChangeWithDeviceMigrationId:accountMigrationId status:status];
            });
        }
    }

    if (status.state == TLAccountMigrationStateStopped) {
        self.currentAccountMigration = nil;
    }
}

- (void)onQueryStatsWithRequestId:(int64_t)requestId peerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo {
    DDLogVerbose(@"%@ onQueryStatsWithRequestId:%lld peerInfo:%@ localInfo:%@", LOG_TAG, requestId, peerInfo, localInfo);
    
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onQueryStatsWithRequestId:peerInfo:localInfo:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLAccountMigrationServiceDelegate>)delegate onQueryStatsWithRequestId:requestId peerInfo:peerInfo localInfo:localInfo];
            });
        }
    }
}

- (void)onTerminateMigrationWithRequestId:(int64_t)requestId deviceMigrationId:(nonnull NSUUID *)deviceMigrationId commit:(BOOL)commit done:(BOOL)done {
    DDLogVerbose(@"%@ onQueryStatsWithRequestId:%lld deviceMigrationId:%@ commit:%@ done:%@", LOG_TAG, requestId, deviceMigrationId.UUIDString, commit ? @"YES":@"NO", done ? @"YES":@"NO");
        
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTerminateMigrationWithRequestId:deviceMigrationId:commit:done:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLAccountMigrationServiceDelegate>)delegate onTerminateMigrationWithRequestId:requestId deviceMigrationId:deviceMigrationId commit:commit done:done];
            });
        }
    }
}

#pragma mark - TLBaseServiceImpl

- (instancetype)initWithTwinlife:(TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    if (self) {
        self.serviceConfiguration = [[TLAccountMigrationServiceConfiguration alloc] init];
        _database = twinlife.databaseService;
        _fileManager = [NSFileManager defaultManager];
    }
    
    return self;
}

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLAccountMigrationServiceConfiguration *accountMigrationServiceConfiguration = [[TLAccountMigrationServiceConfiguration alloc] init];
    
    TLAccountMigrationServiceConfiguration *serviceConfiguration = (TLAccountMigrationServiceConfiguration *)baseServiceConfiguration;
    
    accountMigrationServiceConfiguration.serviceOn = serviceConfiguration.serviceOn;
    self.serviceConfiguration = accountMigrationServiceConfiguration;
    self.serviceOn = accountMigrationServiceConfiguration.isServiceOn;
    self.configured = YES;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    self.databasePath = self.twinlife.databasePath;
    
    self.activeMigrationId = [self checkActiveAccountMigrationIdWithRootDirectory:[TLTwinlife getAppGroupURL:self.fileManager].path databaseDirectory:[self.databasePath stringByDeletingLastPathComponent]];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    [super onTwinlifeOnline];
    
    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (accountMigration) {
        [accountMigration onTwinlifeOnline];
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    [super onDisconnect];
    
    TLAccountMigrationExecutor *accountMigration = self.currentAccountMigration;
    
    if (accountMigration) {
        [accountMigration onDisconnect];
    }
}

#pragma mark - AccountMigration - internal

- (nullable NSUUID *)checkActiveAccountMigrationIdWithRootDirectory:(nullable NSString *)rootDirectory databaseDirectory:(nullable NSString *)databaseDirectory {
    DDLogVerbose(@"%@ checkActiveAccountMigrationIdWithRootDirectory: %@ databaseDirectory: %@", LOG_TAG, rootDirectory, databaseDirectory);
    
    if (!rootDirectory) {
        return nil;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *migrationDirectory = [rootDirectory stringByAppendingPathComponent:MIGRATION_DIR];
    
    if (![fm fileExistsAtPath:migrationDirectory]) {
        return nil;
    }
    
    NSString *migrationIdFile = [migrationDirectory stringByAppendingPathComponent:MIGRATION_ID];
    
    if (![fm fileExistsAtPath:migrationIdFile]) {
        [self cancelMigrationWithRootDirectory:rootDirectory databaseDirectory:databaseDirectory];
        return nil;
    }
    
    NSFileHandle *migrationIdHandle = [NSFileHandle fileHandleForReadingAtPath:migrationIdFile];
    
    NSData *data;
    
    @try {
        data = [migrationIdHandle readDataOfLength:256];
    } @catch (NSException *exception) {
        [self cancelMigrationWithRootDirectory:rootDirectory databaseDirectory:databaseDirectory];
        return nil;
    }
    
    NSUUID *result = [[NSUUID alloc] initWithUUIDString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    
    if (!result) {
        [self cancelMigrationWithRootDirectory:rootDirectory databaseDirectory:databaseDirectory];
        return nil;
    }
    
    return result;
}

- (BOOL)commitConfigurationWithRootDirectory:(nonnull NSString *)rootDirectory {
    DDLogVerbose(@"%@ commitConfigurationWithRootDirectory:%@", LOG_TAG, rootDirectory);

    //
    // Step 1: Verify we have everything before switching the account.
    //
    
    NSString *migratedConfigKey = [MIGRATION_PREFIX stringByAppendingString:TWINLIFE_SECURED_CONFIGURATION_KEY];
    NSString *migratedAccountConfigKey = [MIGRATION_PREFIX stringByAppendingString:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY];

    NSData *secureData = [TLKeyChain getKeyChainDataWithKey:migratedConfigKey tag:nil alternateApplication:NO];
    if (!secureData) {
        return NO;
    }

    NSData *accountData = [TLKeyChain getKeyChainDataWithKey:migratedAccountConfigKey tag:nil alternateApplication:NO];
    if (!accountData) {
        return NO;
    }
    DDLogError(@"%@ secure config:%@", LOG_TAG, secureData);
    DDLogError(@"%@ account config:%@", LOG_TAG, accountData);

    NSString *migratedDbPath = [rootDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V5_NAME];
    NSString *targetDB = CIPHER_V5_DATABASE_NAME;
    if (![self.fileManager fileExistsAtPath:migratedDbPath]) {
        migratedDbPath = [rootDirectory stringByAppendingPathComponent:MIGRATION_DATABASE_CIPHER_V4_NAME];
        targetDB = CIPHER_V4_DATABASE_NAME;
        if (![self.fileManager fileExistsAtPath:migratedDbPath]) {
            return NO;
        }
    }

    NSDictionary<NSUUID *, NSString *> *settings = [TLAccountMigrationExecutor getMigrationSettingsWithMigrationDirectory:[[NSURL fileURLWithPath:rootDirectory] URLByAppendingPathComponent:MIGRATION_DIR]];

    //
    // Step 2: sign-out the current account, deleting almost everything except the keychain and secure configuration.
    //
    
    // Switch to the new account and database.
    [self.twinlife.accountService signOut];
    
    //
    // Step 3: install the new data from the migration directory to the target place.
    //
    if (![TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:secureData alternateApplication:NO]) {
        DDLogError(@"%@ updateKeyChainWithKey failed to store the secured configuration", LOG_TAG);
    }
    if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:accountData alternateApplication:NO]) {
        DDLogError(@"%@ updateKeyChainWithKey failed to store the account configuration", LOG_TAG);
    }
    
    // Erase the existing database (if one of them remain, we could have some trouble when we restart).
    NSString *dest = [rootDirectory stringByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
    if ([self.fileManager fileExistsAtPath:dest]) {
        [self.fileManager removeItemAtPath:dest error:nil];
    }
    dest = [rootDirectory stringByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
    if ([self.fileManager fileExistsAtPath:dest]) {
        [self.fileManager removeItemAtPath:dest error:nil];
    }

    dest = [rootDirectory stringByAppendingPathComponent:targetDB];
    BOOL result;
    NSError *error;

    result = [self.fileManager moveItemAtPath:migratedDbPath toPath:dest error:&error];
    if (!result) {
        DDLogWarn(@"%@ Error while moving database %@ error: %@", LOG_TAG, dest, error);
    }

    NSString *migrationDirectory = [rootDirectory stringByAppendingPathComponent:MIGRATION_DIR];
    NSString *conversationDirectory = [rootDirectory stringByAppendingPathComponent:@"Conversations"];
    NSString *picturesDirectory = [rootDirectory stringByAppendingPathComponent:@"Pictures"];
    NSString *bkpConversationDirectory = [rootDirectory stringByAppendingPathComponent:@"oldConversations"];
    NSString *newConversationDirectory = [migrationDirectory stringByAppendingPathComponent:@"Conversations"];
    NSString *newPicturesDirectory = [migrationDirectory stringByAppendingPathComponent:@"Pictures"];

    [self.fileManager removeItemAtPath:bkpConversationDirectory error:nil];
    
    if ([self.fileManager fileExistsAtPath:conversationDirectory]) {
        error = nil;
        result = [self.fileManager moveItemAtPath:conversationDirectory toPath:bkpConversationDirectory error:&error];
        DDLogWarn(@"%@ Switched conversation %@ to %@, result:%@, error:%@", LOG_TAG, conversationDirectory, bkpConversationDirectory, result ? @"OK":@"KO", error);
        if (!result) {
            [self.fileManager removeItemAtPath:conversationDirectory error:nil];
        }
    }
    
    if ([self.fileManager fileExistsAtPath:newConversationDirectory]) {
        error = nil;
        result = [self.fileManager moveItemAtPath:newConversationDirectory toPath:conversationDirectory error:&error];
        DDLogWarn(@"%@ Switched conversation %@ to %@, result:%@, error:%@", LOG_TAG, newConversationDirectory, conversationDirectory, result ? @"OK":@"KO", error);
    }

    // Install the new settings.
    if (settings) {
        [TLConfigIdentifier importConfig:settings];
    }

    [self.fileManager removeItemAtPath:picturesDirectory error:nil];
    if ([self.fileManager fileExistsAtPath:newPicturesDirectory]) {
        error = nil;
        result = [self.fileManager moveItemAtPath:newPicturesDirectory toPath:picturesDirectory error:&error];
        DDLogWarn(@"%@ Moved pictures %@ to %@, result:%@, error:%@", LOG_TAG, newPicturesDirectory, conversationDirectory, result ? @"OK":@"KO", error);
    }

    //
    // Step 4: cleanup migration markers.
    //
    NSString *hasMigration = [rootDirectory stringByAppendingPathComponent:MIGRATION_DONE];
    [self.fileManager removeItemAtPath:hasMigration error:nil];
    
    // Erase the migrated configuration.
    [TLKeyChain removeKeyChainWithKey:migratedConfigKey tag:nil];
    [TLKeyChain removeKeyChainWithKey:migratedAccountConfigKey tag:nil];

    if ([self.fileManager fileExistsAtPath:bkpConversationDirectory] && ![self.fileManager removeItemAtPath:bkpConversationDirectory error:nil]) {
        DDLogError(@"%@ Old conversations directory was not deleted!", LOG_TAG);
    }

    if ([self.fileManager fileExistsAtPath:migrationDirectory] && ![self.fileManager removeItemAtPath:migrationDirectory error:nil]) {
        DDLogError(@"%@ Migration directory was not deleted!", LOG_TAG);
    }
    
    self.activeMigrationId = nil;
    
    return YES;
}

- (void)finishMigration {
    DDLogVerbose(@"%@ finishMigration", LOG_TAG);

    NSURL *rootDirectory = [TLTwinlife getAppGroupURL:self.fileManager];
    if ([self.fileManager fileExistsAtPath:[rootDirectory.path stringByAppendingPathComponent:MIGRATION_DONE]]) {
        if ([self commitConfigurationWithRootDirectory:rootDirectory.path]) {
            DDLogWarn(@"%@ Account migrated during startup", LOG_TAG);
        } else {
            DDLogError(@"%@ Account migration canceled due to commit error", LOG_TAG);
            [self cancelMigrationWithRootDirectory:rootDirectory.path databaseDirectory:rootDirectory.path];
        }
    }
}

- (void)cleanup {
    DDLogVerbose(@"%@ cleanup", LOG_TAG);

    self.activeMigrationId = nil;
    self.currentAccountMigration = nil;
}

@end
