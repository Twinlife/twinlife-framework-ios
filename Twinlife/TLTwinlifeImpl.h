/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#include <stdatomic.h>
#include <notify.h>

#import "TLServerConnection.h"
#import "TLTwinlife.h"
#import "TLApplication.h"
#import "TLTwinlifeContext.h"

#define TWINLIFE_VERSION @TWINLIFE_FRAMEWORK_VERSION

#define CIPHER_V4_DATABASE_NAME @"twinlife-4.cipher"
#define CIPHER_V5_DATABASE_NAME @"twinlife-5.cipher"

@protocol TLTwinlifeSuspendObserver;

//
// Interface: TLConnectionMonitor
//
@interface TLConnectionMonitor : NSObject

@property volatile BOOL running;

- (nonnull instancetype)init;

@end

//
// Interface: TLTwinlife ()
//

@class TLSerializerFactory;
@class FMDatabaseQueue;
@class TLBaseServiceImplConfiguration;
@class TLTwinlifeSecuredConfiguration;
@class TLProxyDescriptor;
@class TLBinaryPacketIQ;
@class TLSerializerKey;
@class TLBinaryPacketIQSerializer;
@class TLDatabaseService;
@class TLCryptoService;

typedef void (^TLBinaryPacketListener) (TLBinaryPacketIQ * _Nonnull iq);

@interface TLTwinlife () <TLServerConnectionDelegate>

@property (nonnull) TLTwinlifeConfiguration *twinlifeConfiguration;
@property (nullable) TLTwinlifeSecuredConfiguration *twinlifeSecuredConfiguration;

//
// Services
//

@property (readonly, nonnull) TLAccountService *accountService;
@property (readonly, nonnull) TLConnectivityService *connectivityService;
@property (readonly, nonnull) TLConversationService *conversationService;
@property (readonly, nonnull) TLManagementService *managementService;
@property (readonly, nonnull) TLNotificationService *notificationService;
@property (readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (readonly, nonnull) TLRepositoryService *repositoryService;
@property (readonly, nonnull) TLCryptoService *cryptoService;
@property (readonly, nonnull) TLTwincodeFactoryService *twincodeFactoryService;
@property (readonly, nonnull) TLTwincodeInboundService *twincodeInboundService;
@property (readonly, nonnull) TLTwincodeOutboundService *twincodeOutboundService;
@property (readonly, nonnull) TLImageService *imageService;
@property (readonly, nonnull) TLPeerCallService *peerCallService;
@property (readonly, nonnull) TLJobService *jobService;
@property (readonly, nonnull) TLAccountMigrationService *accountMigrationService;
@property (readonly, nonnull) NSArray *twinlifeServices;
@property (readonly, nonnull) TLDatabaseService *databaseService;

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLBinaryPacketListener> *binaryPacketListeners;

@property (readonly, nonnull) dispatch_queue_t serverQueue;
@property (readonly, nonnull) void *serverQueueTag;
@property (nullable) TLServerConnection *serverConnection;
@property (nullable) NSString *model;
@property (nullable) NSString *resource;

@property BOOL inBackground;

@property BOOL configured;
@property BOOL online;
@property BOOL databaseUpgraded;
@property BOOL isInstalled;
@property BOOL connectionFailed; // Set to YES after several attempts to connect.
@property int databaseVersion;
@property atomic_int twinlifeStatus;
@property (nullable) TLConnectionMonitor *connectionMonitor;
@property (nullable) id<TLTwinlifeSuspendObserver> twinlifeSuspendObserver;
@property (nullable) FMDatabaseQueue *databaseQueue;
@property (nullable) NSString *databasePath;
@property (nullable) NSError *databaseError;
@property int connectLockFd;
@property (readonly, nonnull) NSString *connectLockFile;
@property (readonly, nonnull) void *twinlifeQueueTag;
@property int64_t serverTimeCorrection;
@property int estimatedRTT;
@property BOOL forceApplicationRestart;
@property (readonly, nonnull) CFNotificationCenterRef darwinNotificationCenter;
@property int64_t lastSuspendDate;
@property int64_t startTime;
@property int64_t startSuspendTime;
@property int64_t reconnectionTime;

+ (nonnull TLTwinlife *)sharedTwinlife;

+ (int64_t)newRequestId;

+ (BOOL)MANAGEMENT_REPORT_IOS_ID;

+ (nullable NSURL *)getAppGroupURL:(nonnull NSFileManager *)fileManager;

+ (nonnull NSString *)getAppGroupPath:(nonnull NSFileManager *)fileManager path:(nonnull NSString *)path;

+ (nonnull NSUserDefaults *)getAppSharedUserDefaultsWithAlternateApplication:(BOOL)alternateApplication;

+ (nonnull TLBinaryPacketIQSerializer *)IQ_ON_ERROR_SERIALIZER;

+ (BOOL)hasDatabase;

- (void)start;

- (nullable NSString *)getFullJid;

- (BOOL)isConnected;

- (void)connect;

- (void)disconnect;

- (BOOL)isTwinlifeOnline;

- (TLConnectionStatus)connectionStatus;

- (BOOL)isProcessActive:(int)lockIdentifier date:(int64_t)date;

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener;

- (void)onUpdateConfigurationWithConfiguration:(nonnull TLBaseServiceImplConfiguration *)configuration;

- (void)onSignIn;

- (void)onSignOut;

- (void)onTwinlifeOnline;

- (void)twinlifeSuspend;

- (BOOL)twinlifeSuspended;

- (void)twinlifeResume;

- (void)closeDatabase;

- (void)prepareForRestart;

- (nonnull NSString *)toBareJIDWithUsername:(nonnull NSString *)username;

/// Compute the wall clock adjustment between the server and our local clock.
/// This time correction is applied to times that we received from the server.
/// We continue to send our times not-adjusted: the server will do its own correction.
///
/// The algorithm is inspired from NTP but it is simplified:
/// - we compute the RTT between the device and the server,
/// - we compute the time difference between the device and server,
/// - the difference is corrected by RTT/2.
///
/// @param serverTime the server time when it processed the IQ.
/// @param deviceTime the time when we received the server IQ.
/// @param serverLatency the time taken on the server to process the request on its side and respond.
/// @param requestTime the time between our initial request and the server response.
- (void)adjustTimeWithServerTime:(int64_t)serverTime deviceTime:(int64_t)deviceTime serverLatency:(int)serverLatency requestTime:(int64_t)requestTime;

- (void)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

/// Report a failed assertion with a list of assertion values.
- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint, ... NS_REQUIRES_NIL_TERMINATION;

/// Report an unexpected exception associated with an assertion point and a list of values.
- (void)exceptionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nonnull NSException *)exception, ... NS_REQUIRES_NIL_TERMINATION;

- (nonnull NSString *)getDatabaseDiagnostic;

- (nonnull NSString *)getOpenedFileDiagnostic;

#if defined(DEBUG) && DEBUG == 1
/// Internal development method to export the database and other files to the private application area in the 'export' directory.
/// It is intended to be retrieved for development to analyse the content or backup/restore some account for development purposes only.
/// It must not be activated and be compiled for the release.
- (void)developmentExportInternalFiles;

/// Internal development method to import the private application area 'import' to the AppGroup to restore the database, account
/// and files.
- (void)developmentImportExternalFiles;

#endif

@end
