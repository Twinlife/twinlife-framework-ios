/*
 *  Copyright (c) 2014-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBaseService.h"

@class TLQueryInfo;

typedef NS_ENUM(NSInteger, TLAccountMigrationState) {
    TLAccountMigrationStateNone,            // Equivalent to null state in Java
    TLAccountMigrationStateStarting,
    TLAccountMigrationStateNegociate,       // Negotiate size limits before transfer.
    TLAccountMigrationStateListFiles,       // List files with their size and date.
    TLAccountMigrationStateSendFiles,       // Send files in chunks of N kb.
    TLAccountMigrationStateSendSettings,    // Send application settings.
    TLAccountMigrationStateSendDatabase,    // Send database content.
    TLAccountMigrationStateWaitFiles,       // Wait for files and database to be received.
    TLAccountMigrationStateSendAccount,     // Send twinlife secure configuration, account, environmentId.
    TLAccountMigrationStateWaitAccount,     // Wait for peer account.
    TLAccountMigrationStateCheckDatabase,   // Check database and twinlife secure configuration
    TLAccountMigrationStateTerminate,       // Wait for the terminate phase.
    TLAccountMigrationStateTerminated,      // All steps above are processed.
    TLAccountMigrationStateCanceled,        // Operation was canceled.
    TLAccountMigrationStateError,           // Operation aborted due to an error.
    TLAccountMigrationStateStopped          // Stopping or stopped: the executor must not be used.
};

typedef NS_ENUM(NSInteger, TLAccountMigrationErrorCode) {
    TLAccountMigrationErrorCodeNone,
    TLAccountMigrationErrorCodeInternalError,
    TLAccountMigrationErrorCodeNoSpaceLeft,     // Not enough space on the target.
    TLAccountMigrationErrorCodeIoError,         // Read or write error while saving a file.
    TLAccountMigrationErrorCodeRevoked,         // Twincode was revoked (canceled by the peer device ?)
    TLAccountMigrationErrorCodeBadPeerVersion,  // The peer device is not compatible with this device
    TLAccountMigrationErrorCodeBadDatabase,     // Error when checking SQLCipher database with its key.
    TLAccountMigrationErrorCodeSecureStoreError // Error when storing secure configuration
};


//
// Interface: TLAccountMigrationServiceConfiguration
//

@interface TLAccountMigrationServiceConfiguration : TLBaseServiceConfiguration

@end

@interface TLAccountMigrationStatus : NSObject

@property (nonatomic, readonly) TLAccountMigrationState state;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) int64_t bytesSent;
@property (nonatomic, readonly) int64_t estimatedBytesRemainSend;
@property (nonatomic, readonly) int64_t bytesReceived;
@property (nonatomic, readonly) int64_t estimatedBytesRemainReceive;
@property (nonatomic, readonly) double sendProgress;
@property (nonatomic, readonly) double receiveProgress;
@property (nonatomic, readonly) double progress;
@property (nonatomic, readonly) int sendErrorCount;
@property (nonatomic, readonly) int receiveErrorCount;
@property (nonatomic, readonly) TLAccountMigrationErrorCode errorCode;

- (nonnull instancetype)initWithState:(TLAccountMigrationState)state isConnected:(BOOL)isConnected bytesSent:(int64_t)bytesSent estimatedBytesRemainSend:(int64_t)estimatedBytesRemainSend bytesReceived:(int64_t)bytesReceived estimatedBytesRemainReceive:(int64_t)estimatedBytesRemainReceive receiveErrorCount:(int)receiveErrorCount sendErrorCount:(int)sendErrorCount errorCode:(TLAccountMigrationErrorCode)errorCode;

@end

//
// Protocol: TLAccountMigrationServiceDelegate
//

@protocol TLAccountMigrationServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onQueryStatsWithRequestId:(int64_t)requestId peerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo;

- (void)onStatusChangeWithDeviceMigrationId:(nonnull NSUUID *)deviceMigrationId status:( nonnull TLAccountMigrationStatus *)status;

- (void)onTerminateMigrationWithRequestId:(int64_t)requestId deviceMigrationId:(nonnull NSUUID *)deviceMigrationId commit:(BOOL)commit done:(BOOL)done;

@end

//
// Interface: TLAccountMigrationService
//

@interface TLAccountMigrationService : TLBaseService

+ (nonnull NSString *)VERSION;

///Check and get the active device migration id.
- (nullable NSUUID *)getActiveDeviceMigrationId;

///Start the device migration process by setting up and opening the P2P connection to the peer twincode outboundid.
- (void)outgoingStartMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

///Start the device migration process by accepting the incoming P2P connection from the peer.
- (void)incomingStartMigrationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId accountMigrationId:(nonnull NSUUID *)accountMigrationId peerTwincodeOutboundId:(nullable NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

///Query the peer device to obtain statistics about the files it provides.
- (void)queryStatsWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize;

///Start the migration by asking the peer device to send its files.
- (void)startMigrationWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize;

///Terminate the migration by sending the termination IQ and closing the P2P connection.
- (void)terminateMigrationWithRequestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done;

///Shutdown the P2P connection gracefully after the terminate phase1 and phase2.
- (void)shutdownMigrationWithRequestId:(int64_t)requestId;

///Cancel a possible device migration:
/// - if there is a P2P connection close it,
/// - if there is an active (ie, opened) device migration engine stop it,
/// - if there are some migration files, remove them.
/// Last, notify a possible migration service that the migration was canceled.
- (BOOL)cancelMigrationWithDeviceMigrationId:(nonnull NSUUID *)deviceMigrationId;

- (void)cancelMigrationWithRootDirectory:(nonnull NSString*)rootDirectory databaseDirectory:(nullable NSString *)databaseDirectory;

- (void)setProgressWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId status:(nonnull TLAccountMigrationStatus *)status;

- (BOOL)commitConfigurationWithRootDirectory:(nonnull NSString *)rootDirectory;

- (void)cleanup;

- (void)onQueryStatsWithRequestId:(int64_t)requestId peerInfo:(nonnull TLQueryInfo *)peerInfo localInfo:(nonnull TLQueryInfo *)localInfo;

- (void)onTerminateMigrationWithRequestId:(int64_t)requestId deviceMigrationId:(nonnull NSUUID *)deviceMigrationId commit:(BOOL)commit done:(BOOL)done;

@end
