/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#include <stdlib.h>
#import  <libkern/OSAtomic.h>

#import <CocoaLumberjack.h>

#import "TLTwinlifeImpl.h"
#import "TLTwinlifeContext.h"
#import "TLTwinlifeContext+Protected.h"
#import "TLAccountServiceImpl.h"
#import "TLConnectivityServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLJobServiceImpl.h"

#define GLOBAL_ERROR_DELAY_GUARD (2 * 120 * 1000) // 2 minutes

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLTwinlifeContext ()
//

@class AccountServiceDelegate;
@class ConnectivityServiceDelegate;
@class ManagementServiceDelegate;

@interface TLTwinlifeContext ()

@property TLTwinlifeConfiguration *configuration;
@property BOOL twinlifeOnline;
@property TLBaseServiceErrorCode configureStatus;

@property AccountServiceDelegate *accountServiceDelegate;
@property ConnectivityServiceDelegate *connectivityServiceDelegate;
@property ManagementServiceDelegate *managementServiceDelegate;

- (void)onValidateConfiguration;

@end

//
// Interface: AccountServiceDelegate
//

@interface AccountServiceDelegate : NSObject <TLAccountServiceDelegate>

@property (weak) TLTwinlifeContext* context;

- (instancetype)initWithContext:(TLTwinlifeContext *)context;

- (void)onSignIn;

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSignOut;

@end

//
// Implementation: AccountServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"AccountServiceDelegate"

@implementation AccountServiceDelegate

- (instancetype)initWithContext:(TLTwinlifeContext *)context {
    DDLogVerbose(@"%@ initWithContext: %@", LOG_TAG, context);
    
    self = [super init];
    
    if (self) {
        _context = context;
    }
    return self;
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    [self.context onSignIn];
}

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onSignInErrorWithErrorCode: %d", LOG_TAG, errorCode);
    
    [self.context onSignInErrorWithErrorCode:errorCode];
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [self.context onSignOut];
}

@end

//
// Interface: ConnectivityServiceDelegate
//

@interface ConnectivityServiceDelegate : NSObject <TLConnectivityServiceDelegate>

@property (weak) TLTwinlifeContext* context;

- (instancetype)initWithContext:(TLTwinlifeContext *)context;

@end

//
// Implementation: ConnectivityServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ConnectivityServiceDelegate"

@implementation ConnectivityServiceDelegate

- (instancetype)initWithContext:(TLTwinlifeContext *)context {
    DDLogVerbose(@"%@ initWithContext: %@", LOG_TAG, context);
    
    self = [super init];
    
    if (self) {
        _context = context;
    }
    return self;
}

- (void)onNetworkConnect {
    DDLogVerbose(@"%@ onNetworkConnect", LOG_TAG);
    
    [self.context onNetworkConnect];
}

- (void)onNetworkDisconnect {
    DDLogVerbose(@"%@ onNetwrokDisconnect", LOG_TAG);
    
    [self.context onNetworkDisconnect];
}

- (void)onConnect {
    DDLogVerbose(@"%@ onConnect", LOG_TAG);
    
    [self.context onConnect];
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    [self.context onDisconnect];
}

@end

//
// Interface: ManagementServiceDelegate
//

@interface ManagementServiceDelegate : NSObject <TLManagementServiceDelegate>

@property (weak)TLTwinlifeContext* context;
@property int64_t lastErrorTime;

- (instancetype)initWithContext:(TLTwinlifeContext *)context;

@end

//
// Implementation: ManagementServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"ManagementServiceDelegate"

@implementation ManagementServiceDelegate

- (instancetype)initWithContext:(TLTwinlifeContext *)context {
    DDLogVerbose(@"%@ initWithContext: %@", LOG_TAG, context);
    
    self = [super init];
    
    if (self) {
        _context = context;
    }
    return self;
}

- (void)onValidateConfigurationWithRequestId:(int64_t) requestId {
    DDLogVerbose(@"%@ onValidateConfigurationWithRequestId: %lld", LOG_TAG, requestId);
    
    [self.context onValidateConfiguration];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    
    if (requestId == [TLBaseService DEFAULT_REQUEST_ID]) {
        
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        if (now < self.lastErrorTime + GLOBAL_ERROR_DELAY_GUARD ) {
            return;
        }

        self.lastErrorTime = now;
        [self.context fireOnErrorWithRequestId:requestId errorCode:errorCode errorParameter:errorParameter];
    }
}

@end

//
// Implementation: TLTwinlifeContext
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeContext"

@implementation TLTwinlifeContext

- (instancetype)initWithConfiguration:(TLTwinlifeConfiguration *)configuration {
    DDLogVerbose(@"%@ initWithConfiguration: %@", LOG_TAG, configuration);
    
    self =  [super init];
    
    if (self) {
        _twinlife = [TLTwinlife sharedTwinlife];
        _twinlife.twinlifeSuspendObserver = self;
        _configuration = configuration;
        _twinlifeOnline = NO;
        _configureStatus = TLBaseServiceErrorCodeSuccess;
        
        if (configuration.enableSetup) {
            [_twinlife.jobService registerBackgroundTasks];
        }

        _delegates = [[NSMutableSet alloc] init];
        
        _accountServiceDelegate = [[AccountServiceDelegate alloc] initWithContext:self];
        _connectivityServiceDelegate = [[ConnectivityServiceDelegate alloc] initWithContext:self];
        _managementServiceDelegate = [[ManagementServiceDelegate alloc] initWithContext:self];
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);

    // Start Twinlife from its twinlife queue to avoid blocking the main thread.
    dispatch_async([self.twinlife twinlifeQueue], ^{
        // Configure the first time start is called.
        TLTwinlifeStatus status = self.status;
        DDLogVerbose(@"%@ start status=%d", LOG_TAG, status);
        if (status == TLTwinlifeStatusUninitialized) {
            self.configureStatus = [self.twinlife configure:self.configuration];
            if (self.configureStatus != TLBaseServiceErrorCodeSuccess) {
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onFatalErrorWithErrorCode:databaseError:)]) {
                        id<TLTwinlifeContextDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onFatalErrorWithErrorCode:self.configureStatus databaseError:self.twinlife.databaseError];
                        });
                    }
                }
                DDLogVerbose(@"%@ start configure error %d", LOG_TAG, self.configureStatus);
                return;
            }
            status = self.status;
        }

        // Do nothing if we are already started.
        if (status == TLTwinlifeStatusStarted) {
            DDLogVerbose(@"%@ start already started!!!!", LOG_TAG);
            return;
        }

        [self.twinlife start];
    
        if (status != TLTwinlifeStatusSuspended) {
            [[self getAccountService] addDelegate:self.accountServiceDelegate];
            [[self getConnectivityService] addDelegate:self.connectivityServiceDelegate];
            [[self getManagementService] addDelegate:self.managementServiceDelegate];
        }
        [self onTwinlifeReady];

        if (status != TLTwinlifeStatusSuspended) {
            [self addDelegate:self.twinlife.jobService];
        }
    });
}

- (void)stopWithCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler {
    DDLogVerbose(@"%@ stopWithCompletionHandler", LOG_TAG);
    
    [self.twinlife stopWithCompletionHandler:completionHandler];
}

- (TLTwinlifeStatus)status {
    DDLogVerbose(@"%@ status", LOG_TAG);

    return [self.twinlife status];
}

- (BOOL)isConnected {
    DDLogVerbose(@"%@ isConnected", LOG_TAG);
    
    return self.twinlife && [self.twinlife isConnected];
}

- (BOOL)isTwinlifeOnline {
    DDLogVerbose(@"%@ isTwinlifeOnline", LOG_TAG);
    
    return self.twinlifeOnline;
}

- (TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ connectionStatus", LOG_TAG);

    if (!self.twinlife) {
        return TLConnectionStatusNoService;
    } else {
        return [self.twinlife connectionStatus];
    }
}

- (void)connect {
    DDLogVerbose(@"%@ connect", LOG_TAG);

    [self.twinlife connect];
}

- (int64_t)newRequestId {
    DDLogVerbose(@"%@ newRequestId", LOG_TAG);
    
    return [TLTwinlife newRequestId];
}

- (void)addDelegate:(id)delegate {
    DDLogVerbose(@"%@ addDelegate: %@", LOG_TAG, delegate);

    TLBaseServiceErrorCode configureStatus;
    TLTwinlifeStatus status;
    @synchronized(self) {
        if ([self.delegates containsObject:delegate]) {
            return;
        }
        self.delegates = [self.delegates setByAddingObject:delegate];
        status = [self status];

        // We must wait until the twinlife library is started or in error.
        if (status != TLTwinlifeStatusStarted && status != TLTwinlifeStatusError) {
            return;
        }
        configureStatus = self.configureStatus;
    }

    // If there is a configuration error, stop and report it.
    if (configureStatus != TLBaseServiceErrorCodeSuccess) {
        if ([delegate respondsToSelector:@selector(onFatalErrorWithErrorCode:databaseError:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [delegate onFatalErrorWithErrorCode:configureStatus databaseError:self.twinlife.databaseError];
            });
        }
        return;
    }

    NSAssert(status == TLTwinlifeStatusStarted, @"twinlife.status must be started");

    if ([delegate respondsToSelector:@selector(onTwinlifeReady)]) {
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [delegate onTwinlifeReady];
        });
    }
    if ([self.twinlife isConnected]) {
        if ([delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [delegate onConnectionStatusChange:TLConnectionStatusConnected];
            });
        }
        if ([[self getAccountService] isSignIn]) {
            if ([delegate respondsToSelector:@selector(onSignIn)]) {
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [delegate onSignIn];
                });
            }
            if ([[self getManagementService] hasValidatedConfiguration]) {
                if ([delegate respondsToSelector:@selector(onTwinlifeOnline)]) {
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [delegate onTwinlifeOnline];
                    });
                }
            }
        }
    }
}

- (void)removeDelegate:(id)delegate {
    DDLogVerbose(@"%@ removeDelegate:%@", LOG_TAG, delegate);

    // Copy on delete to avoid changing the delegates set while other threads are dispatching.
    @synchronized(self) {
        NSMutableSet *delegates = [NSMutableSet setWithSet:self.delegates];
        [delegates removeObject:delegate];
        self.delegates = delegates;
    }
}

- (TLAccountService *)getAccountService {
    
    return [self.twinlife getAccountService];
}

- (TLConnectivityService *)getConnectivityService {
    
    return [self.twinlife getConnectivityService];
}

- (TLConversationService *)getConversationService {
    
    return [self.twinlife getConversationService];
}

- (TLManagementService *)getManagementService {
    
    return [self.twinlife getManagementService];
}

- (TLNotificationService *)getNotificationService {
    
    return [self.twinlife getNotificationService];
}

- (TLPeerConnectionService *)getPeerConnectionService {
    
    return [self.twinlife getPeerConnectionService];
}

- (TLRepositoryService *)getRepositoryService {
    
    return [self.twinlife getRepositoryService];
}

- (TLTwincodeFactoryService *)getTwincodeFactoryService {
    
    return [self.twinlife getTwincodeFactoryService];
}

- (TLTwincodeInboundService *)getTwincodeInboundService {
    
    return [self.twinlife getTwincodeInboundService];
}

- (TLTwincodeOutboundService *)getTwincodeOutboundService {
    
    return [self.twinlife getTwincodeOutboundService];
}

- (TLImageService *)getImageService {
    
    return [self.twinlife getImageService];
}

- (TLPeerCallService *)getPeerCallService {
    
    return [self.twinlife getPeerCallService];
}

- (TLJobService *)getJobService {

    return [self.twinlife getJobService];
}

- (TLAccountMigrationService *)getAccountMigrationService {
    return [self.twinlife getAccountMigrationService];
}

- (TLSerializerFactory *)getSerializerFactory {

    return [self.twinlife serializerFactory];
}

- (NSDictionary<NSString *, TLServiceStats *> *)getServiceStats {

    return [self.twinlife getServiceStats];
}

- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint, ... NS_REQUIRES_NIL_TERMINATION {
    DDLogVerbose(@"%@ assertionWithAssertPoint: %@", LOG_TAG, assertPoint);

    va_list args;
    va_start(args, assertPoint);
    [self.twinlife.managementService assertionWithAssertPoint:assertPoint exception:nil vaList:args];
    va_end(args);
}

- (void)exceptionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nonnull NSException *)exception, ... NS_REQUIRES_NIL_TERMINATION {
    DDLogVerbose(@"%@ exceptionWithAssertPoint: %@ exception: %@", LOG_TAG, assertPoint, exception);

    va_list args;
    va_start(args, exception);
    [self.twinlife.managementService assertionWithAssertPoint:assertPoint exception:exception vaList:args];
    va_end(args);
}

//
// Error management
//

- (void)fireOnErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ fireOnErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onErrorWithRequestId:errorCode:errorParameter:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter];
            });
        }
    }
}

//
// Protected Methods
//

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTwinlifeReady)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTwinlifeReady];
            });
        }
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    self.twinlifeOnline = YES;
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTwinlifeOnline)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTwinlifeOnline];
            });
        }
    }
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTwinlifeSuspend)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTwinlifeSuspend];
            });
        }
    }
}

- (void)onTwinlifeResume {
    DDLogVerbose(@"%@ onTwinlifeResume", LOG_TAG);

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTwinlifeResume)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTwinlifeResume];
            });
        }
    }
}

- (void)onNetworkConnect {
    DDLogVerbose(@"%@ onNetworkConnect", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onConnectionStatusChange:TLConnectionStatusConnecting];
            });
        }
    }
}

- (void)onNetworkDisconnect {
    DDLogVerbose(@"%@ onNetworkDisconnect", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onConnectionStatusChange:TLConnectionStatusNoInternet];
            });
        }
    }
}

- (void)onConnect  {
    DDLogVerbose(@"%@ onConnect", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onConnectionStatusChange:TLConnectionStatusConnected];
            });
        }
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    self.twinlifeOnline = NO;
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTwinlifeOffline)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onTwinlifeOffline];
            });
        }
    }
    
    TLConnectionStatus connectionStatus = [self.twinlife connectionStatus];
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onConnectionStatusChange:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onConnectionStatusChange:connectionStatus];
            });
        }
    }
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSignIn)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onSignIn];
            });
        }
    }
}

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onSignInErrorWithErrorCode", LOG_TAG);

    // This is a serious error and we cannot proceed, invalidate any operation from now.
    // It occurs if:
    // - the Twinme Configuration is incorrect (ex: bad application id, bad service id, ...)
    // - the user account has been deleted.
    self.configureStatus = errorCode;

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onFatalErrorWithErrorCode:databaseError:)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onFatalErrorWithErrorCode:errorCode databaseError:self.twinlife.databaseError];
            });
        }
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSignOut)]) {
            id<TLTwinlifeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onSignOut];
            });
        }
    }
}

#pragma mark - Private methods

- (void)onValidateConfiguration {
    DDLogVerbose(@"%@ onValidateConfiguration", LOG_TAG);
    
    [self onTwinlifeOnline];
}

@end
