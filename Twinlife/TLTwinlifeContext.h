/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

/**
 *
 *  onTwinlifeReady
 *
 *  onNetworkConnect
 *  onNetworkDisconnect
 *
 *  onConnect
 *   onSignIn
 *    onTwinlifeOnline
 *    onTwinlifeOffline
 *
 *  onDisconnect
 *
 *  onTwinlifeSuspend (before OS suspension)
 *  onTwinlifeResume (after OS suspension)
 *
 *  onSignOut
 **/

#import "TLBaseService.h"

//
// Interface: TLTwinlifeSuspendObserver
//
@protocol TLTwinlifeSuspendObserver

- (void)onTwinlifeSuspend;

- (void)onTwinlifeResume;

@end

//
// Protocol: TLTwinlifeContextDelegate
//

@protocol TLTwinlifeContextDelegate
@optional

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onTwinlifeSuspend;

- (void)onTwinlifeResume;

// Connectivity Management

- (void)onConnectionStatusChange:(TLConnectionStatus)connectionStatus;

// Account Management

- (void)onSignIn;

- (void)onSignOut;

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

- (void)onFatalErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode databaseError:(NSError *)databaseError;

@end

//
// Interface: TLTwinlifeContext
//

@class TLTwinlife;
@class TLTwinlifeConfiguration;
@class TLAssertPoint;
@class TLAssertValue;

@class TLAccountService;
@class TLConnectivityService;
@class TLConversationService;
@class TLManagementService;
@class TLNotificationService;
@class TLPeerConnectionService;
@class TLRepositoryService;
@class TLTwincodeFactoryService;
@class TLTwincodeInboundService;
@class TLTwincodeOutboundService;
@class TLImageService;
@class TLPeerCallService;
@class TLJobService;
@class TLAccountMigrationService;
@class TLSerializerFactory;

@interface TLTwinlifeContext : NSObject <TLTwinlifeSuspendObserver>

@property (weak) TLTwinlife *twinlife;

@property NSSet *delegates;

- (instancetype)initWithConfiguration:(TLTwinlifeConfiguration *)configuration;

- (void)start;

- (void)stopWithCompletionHandler:(void (^)(TLBaseServiceErrorCode status))completionHandler;

- (BOOL)isConnected;

- (BOOL)isTwinlifeOnline;

- (TLTwinlifeStatus)status;

/// Get the connection status
- (TLConnectionStatus)connectionStatus;

- (void)connect;

- (int64_t)newRequestId;

- (void)addDelegate:(id)delegate;

- (void)removeDelegate:(id)delegate;

- (TLAccountService *)getAccountService;

- (TLConnectivityService *)getConnectivityService;

- (TLConversationService *)getConversationService;

- (TLNotificationService *)getNotificationService;

- (TLManagementService *)getManagementService;

- (TLPeerConnectionService *)getPeerConnectionService;

- (TLRepositoryService *)getRepositoryService;

- (TLTwincodeFactoryService *)getTwincodeFactoryService;

- (TLTwincodeInboundService *)getTwincodeInboundService;

- (TLTwincodeOutboundService *)getTwincodeOutboundService;

- (TLImageService *)getImageService;

- (TLPeerCallService *)getPeerCallService;

- (TLJobService *)getJobService;

- (TLAccountMigrationService *)getAccountMigrationService;

- (TLSerializerFactory *)getSerializerFactory;

- (NSDictionary<NSString *, TLServiceStats *> *)getServiceStats;

- (void)fireOnErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

/// Report a failed assertion with a list of assertion values.
- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint, ... NS_REQUIRES_NIL_TERMINATION;

/// Report an unexpected exception associated with an assertion point and a list of values.
- (void)exceptionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nonnull NSException *)exception, ... NS_REQUIRES_NIL_TERMINATION;

@end
