/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import "TLPeerConnectionService.h"
#import "TLPeerConnectionHandler.h"
#import "TLAccountMigrationService.h"
#import "TLTwinlifeImpl.h"

#define PREFERENCES @"ManagementService"
#define MIGRATION_PREFIX @"Migration"

#define MIGRATION_DATABASE_NAME            @"migration.db"
#define MIGRATION_DATABASE_CIPHER_V3_NAME  @"migration-3.sqlcipher"
#define MIGRATION_DATABASE_CIPHER_V4_NAME  @"migration-4.sqlcipher"
#define MIGRATION_DATABASE_CIPHER_V5_NAME  @"migration-5.sqlcipher"

#define MIGRATION_DIR @"Migration"
#define MIGRATION_DONE @"migration-done"
#define MIGRATION_ID @"migration-id"

@class TLDatabaseService;

//
// Interface: TLAccountMigrationHandler
//

@interface TLAccountMigrationHandler : TLPeerConnectionHandler

@end


/**
 * This class holds the state of the migration process between the two devices.
 *
 * 1/ Scan the directory to export recursively the files
 *    => mListFiles is populated with a list of files, paths are relative to the application directory.
 * 2/ Statistics are exchanged so that the user can decide whether we define a limit for a file size.
 *    => mListFiles is looked to compute such stats.
 * 3/ Send list of files with information in batch of 64-files max taking into account the file size limit
 *    => mListFiles is cleaned while the list is sent to the peer
 *       mSendingFiles is populated with the list of files
 *       files bigger that mMaxFileSize are dropped.
 * 4/ Send data blocks.
 * 5/ Send the application settings.
 * 6/ Send the database.
 *    IMPORTANT NOTE: the database file must be copied in the location pointed to by Android getDatabasePath()
 *    otherwise, the renameTo() that we are doing can fail.  We must also handle the copy of either twinlife.db
 *    or twinlife.cipher or twinlife-4.cipher: it can happen that there was not enough space for the SQLcipher
 *    database migration.
 * 7/ Send the account information.
 * 8/ Terminate and prepare the commit phase.
 * 9/ Do the commit by replacing files, database and settings.
 *
 * The account migration progress is made with the following variables:
 *
 * mSent indicates the number of bytes for files that have been successfully transferred (updated by processOnPutFile).
 *
 * mSendTotal is the total number of bytes that must be transferred including the database (updated by processOnListFiles).
 *
 * mSendPending defines the number of bytes that have been sent but not yet fully acknowledged.  If a file transfer aborts
 * and produces an error, it is decremented.  It is incremented by sendFileChunk() and decremented by processOnPutFile().
 *
 * mReceived is the total number of bytes received (similar to mSent, updated by processPutFile).
 *
 * mReceiveTotal is the total number of bytes that we must receive including the database (updated by processListFiles).
 *
 * mReceivePending is the total number of bytes received but not yet acknowledged.  It is incremented or decremented
 * by processPutFile() according to the file transfer.
 *
 * A FileInfoImpl instances are moved across the Map as follows:
 *
 * [scanDirectory() => mListFiles] -> [sendListFiles() => mWaitListFiles] -> [processOnListFiles() => mSendingFiles]
 *
 * During a file transfer, the FileInfoImpl can move as follows:
 *
 * [sendFileChunk() => mWaitAckFiles] -> [processOnPutFile() => deleted if file transfer OK]
 *                                    -> [processOnPutFile() => mSendingFiles if file transfer KO]
 *
 * For the receiving side, the FileInfoImpl instances are inserted by processListFiles() and removed when a successful
 * transfer is made by processPutFile().
 *
 * When we are disconnected and we re-connect, the account migration executor must invalide all the above information
 * and start with a new fresh state.  This is done in three steps:
 *
 * - cleanup() is called at disconnection time to close the opened files, cleanup the FileInfoImpl maps,
 * - scanDirectory() is called at disconnection time to get a fresh new accurate mListFiles map,
 * - progress counters are cleared by onOpenDataChannel() when we are re-connected.
 *
 */

@interface TLAccountMigrationExecutor : TLPeerConnectionHandler

@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (readonly, nonnull) NSUUID *accountMigrationId;
@property (nonatomic) TLAccountMigrationState state;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife accountMigrationService:(nonnull TLAccountMigrationService *)accountMigrationService databaseService:(nonnull TLDatabaseService *)databaseService databaseFile:(nonnull NSURL *)databaseFile accountMigrationId:(nonnull NSUUID *)accountMigrationId peerId:(nonnull NSString *)peerId rootDirectory:(nonnull NSURL *)rootDirectory;

- (BOOL)isConnected;

- (BOOL)canTerminate;

- (void)cancel;

- (void)updateProgress;

-(void)queryStatsWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize;

-(void)startMigrationWithRequestId:(int64_t)requestId maxFileSize:(int64_t)maxFileSize;

- (void)terminateMigrationWithRequestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done;

- (void)shutdownMigrationWithRequestId:(int64_t)requestId;

+ (nullable NSDictionary<NSUUID *, NSString *> *)getMigrationSettingsWithMigrationDirectory:(nonnull NSURL *)migrationDirectoryURL;

//- (void)stopWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

@end
