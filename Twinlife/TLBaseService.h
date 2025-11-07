/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
*/
#import <stdatomic.h>

/// Default timeout for a server request.
#define DEFAULT_REQUEST_TIMEOUT 20.0 // seconds

/// Extra delay in seconds to wait before checking for a request operation to timeout.
#define TIMEOUT_CHECK_DELAY 2.0 // seconds

/**
 * Timeout management
 *
 * The timeout management is global to a service instance: there is only one timeout deadline for all pending requests.
 * This allows to have a simple implementation but the timeout is less precise.
 *
 * When a first request is sent, a timeout deadline is computed for the request and a Job is scheduled with the JobService.
 * The job is scheduled TIMEOUT_CHECK_DELAY (2.0) seconds after the deadline. The requestId is added to the pendingRequestIdList set.
 *
 * When another request is sent, a new deadline time is computed and it replaces the current deadline. The scheduled job
 * is not modified. The requestId is also added to the pendingRequestIdList set.
 *
 * When the timeout job is executed, we look at the deadline and if it was passed, all pending requests are reported
 * with an error.  If the deadline has not passed and we still have pending requests, a new job is scheduled TIMEOUT_CHECK_DELAY
 * seconds after the deadline.
 *
 * When a response is received, we expect the receive handler to call receivedIQ so that we remove the requestId from the pending list.
 */

typedef enum {
    TLBaseServiceIdAccountService,
    TLBaseServiceIdConnectivityService,
    TLBaseServiceIdConversationService,
    TLBaseServiceIdManagementService,
    TLBaseServiceIdNotificationService,
    TLBaseServiceIdPeerConnectionService,
    TLBaseServiceIdRepositoryService,
    TLBaseServiceIdTwincodeFactoryService,
    TLBaseServiceIdTwincodeInboundService,
    TLBaseServiceIdTwincodeOutboundService,
    TLBaseServiceIdImageService,
    TLBaseServiceIdPeerCallService,
    TLBaseServiceIdCryptoService
} TLBaseServiceId;

typedef enum {
    TLBaseServiceErrorCodeSuccess,
    TLBaseServiceErrorCodeBadRequest,
    TLBaseServiceErrorCodeCanceledOperation,
    TLBaseServiceErrorCodeFeatureNotImplemented,
    TLBaseServiceErrorCodeFeatureNotSupportedByPeer,
    TLBaseServiceErrorCodeServerError,
    TLBaseServiceErrorCodeItemNotFound,
    TLBaseServiceErrorCodeLibraryError,
    TLBaseServiceErrorCodeLibraryTooOld,
    TLBaseServiceErrorCodeNotAuthorizedOperation,
    TLBaseServiceErrorCodeServiceUnavailable,
    TLBaseServiceErrorCodeTwinlifeOffline,
    TLBaseServiceErrorCodeWebrtcError,
    TLBaseServiceErrorCodeWrongLibraryConfiguration,
    TLBaseServiceErrorCodeNoStorageSpace,
    TLBaseServiceErrorCodeNoPermission,
    TLBaseServiceErrorCodeLimitReached,
    TLBaseServiceErrorCodeDatabaseError,
    TLBaseServiceErrorCodeDatabaseKeyError,
    TLBaseServiceErrorCodeTimeoutError,
    TLBaseServiceErrorCodeAccountDeleted,
    TLBaseServiceErrorCodeQueued,
    TLBaseServiceErrorCodeQueuedNoWakeup,
    TLBaseServiceErrorCodeExpired,
    TLBaseServiceErrorCodeInvalidPublicKey,
    TLBaseServiceErrorCodeInvalidPrivateKey,
    TLBaseServiceErrorCodeNoPublicKey,
    TLBaseServiceErrorCodeNoPrivateKey,
    TLBaseServiceErrorCodeNoSecretKey,
    TLBaseServiceErrorCodeNotEncrypted,
    TLBaseServiceErrorCodeBadSignature,
    TLBaseServiceErrorCodeBadSignatureFormat,
    TLBaseServiceErrorCodeBadSignatureMissingAttribute,
    TLBaseServiceErrorCodeBadSignatureNotSignedAttribute,
    TLBaseServiceErrorCodeEncryptError,
    TLBaseServiceErrorCodeDecryptError,
    TLBaseServiceErrorCodeBadEncryptionFormat,
    TLBaseServiceErrorCodeFileNotFound,
    TLBaseServiceErrorCodeFileNotSupported
} TLBaseServiceErrorCode;

/**
 * Status of the Twinlife library. The status is modified by the start and stop operations.
 */
typedef enum {
    /// Not yet initialized.
    TLTwinlifeStatusUninitialized,

    /// Twinlife is configured
    TLTwinlifeStatusConfigured,

    /// Twinlife is being started
    TLTwinlifeStatusStarting,

    /// Twinlife start was called and we are ready to proceed.
    TLTwinlifeStatusStarted,

    /// The suspend operation was called, we are going to disconnect and suspend.
    TLTwinlifeStatusSuspending,

    /// The suspend operation was called and completed. A Twinlife start is necessary.
    TLTwinlifeStatusSuspended,

    /// Twinlife is stopped.
    TLTwinlifeStatusStopped,

    /// Twinlife configuration failed.
    TLTwinlifeStatusError
} TLTwinlifeStatus;

typedef enum {
    // Not connected because there is no Internet connection.
    TLConnectionStatusNoInternet,

    // Internet connection detected but we timed out in connecting to the server.
    TLConnectionStatusNoService,

    // Currently trying to connect.
    TLConnectionStatusConnecting,

    // Connected to the server.
    TLConnectionStatusConnected
} TLConnectionStatus;

typedef enum {
    TLDisplayCallsModeNone,
    TLDisplayCallsModeMissed,
    TLDisplayCallsModeAll
} TLDisplayCallsMode;

@class TLBinaryErrorPacketIQ;
@class TLBinaryPacketIQ;
@class TLSerializerFactory;

//
// Interface: TLServiceStats
//

@interface TLServiceStats : NSObject

@property int sendPacketCount;
@property int sendErrorCount;
@property int sendDisconnectedCount;
@property int sendTimeoutCount;
@property int databaseFullCount;
@property int databaseErrorCount;

- (nonnull instancetype)initWithCount:(int)sendCount errorCount:(int)errorCount disconnectedCount:(int)disconnectedCount timeoutCount:(int)timeoutCount;

@end

//
// Interface: TLTurnServer
//

@interface TLTurnServer : NSObject

@property (readonly, nonnull) NSString *url;
@property (readonly, nonnull) NSString *username;
@property (readonly, nonnull) NSString *password;

- (nonnull instancetype)initWithUrl:(nonnull NSString *)url username:(nonnull NSString *)username password:(nonnull NSString *)password;

@end

//
// Interface: TLBaseServiceConfiguration
//

@interface TLBaseServiceConfiguration : NSObject

@property TLBaseServiceId baseServiceId;
@property (nonnull) NSString *version;
@property (getter=isServiceOn) BOOL serviceOn;
@property (nonnull) NSMutableArray *turnServers;

- (nonnull instancetype)initWithBaseServiceId:(TLBaseServiceId)baseServiceId version:(nonnull NSString *)version serviceOn:(BOOL)serviceOn;

@end

//
// Protocol: TLBaseServiceDelegate
//

@protocol TLBaseServiceDelegate <NSObject>
@optional

- (void)onError:(nonnull NSString *)errorCode requestId:(int64_t)requestId errorParameter:(nullable NSString *)errorParameter service:(NSInteger)serviceId;

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorcode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: TLBaseService
//

@interface TLBaseService : NSObject

+ (int64_t)UNDEFINED_REQUEST_ID;

+ (int64_t)DEFAULT_REQUEST_ID;

+ (nonnull NSNumber *)newRequestId;

+ (int)fromErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (TLBaseServiceErrorCode)toErrorCode:(int)errorCode;

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate;

- (void)removeDelegate:(nonnull id<TLBaseServiceDelegate>)delegate;

- (TLBaseServiceId)getBaseServiceId;

- (nonnull NSString *)getVersion;

- (nonnull NSString *)getServiceName;

/// Get the service send statistics.
- (nonnull TLServiceStats *)getServiceStats;

- (BOOL)isSignIn;

- (BOOL)isTwinlifeOnline;

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ;

- (TLBaseServiceErrorCode)onDatabaseErrorWithError:(nonnull NSError *)error line:(int)line;

- (TLBaseServiceErrorCode)onDatabaseErrorWithCode:(TLBaseServiceErrorCode)errorCode;

/// Send binary IQ with a timeout.
- (void)sendBinaryIQ:(nonnull TLBinaryPacketIQ *)iq factory:(nonnull TLSerializerFactory *)factory timeout:(NSTimeInterval)timeout;

/// Send a response binary IQ to acknowledge an IQ received from the server.
- (void)sendResponseIQ:(nonnull TLBinaryPacketIQ *)iq factory:(nonnull TLSerializerFactory *)factory;

/// Setup a timeout for the given request Id.
- (void)packetTimeout:(int64_t)requestId timeout:(NSTimeInterval)timeout isBinary:(BOOL)isBinary;

/// Acknowledge the recept of the response IQ associated with a sendIQ message.
- (void)receivedBinaryIQ:(nonnull TLBinaryPacketIQ *)iq;

@end
