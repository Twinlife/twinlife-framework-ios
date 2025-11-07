/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

#ifdef SKRED
    static NSString * _Nonnull const SERVER_NAME = @"skred.mobi";
    static NSString * _Nonnull const SERVER_URL  = @"ws.skred.mobi";
    static NSString * _Nonnull const APP_GROUP_NAME = @"group.mobi.skred.app";
    static NSString * _Nonnull const KEYCHAIN_SERVICE = @"mobi.skred.app";
    static NSString * _Nonnull const TWINME_APP_GROUP_NAME = APP_GROUP_NAME;
    static NSString * _Nonnull const TWINME_KEYCHAIN_SERVICE = KEYCHAIN_SERVICE;
    static NSString * _Nonnull const SCHEDULER_TASK_NAME = @"mobi.skred.scheduler"; // Identifier must be registered in application Info.plist
    static NSString * _Nonnull const INVITATION_PARAM_ID = @"skredcodeId";
#else
    //Twinme(+)
    static NSString * _Nonnull const SCHEDULER_TASK_NAME = @"me.twin.scheduler"; // Identifier must be registered in application Info.plist
    static NSString * _Nonnull const INVITATION_PARAM_ID = @"twincodeId";
    static NSString * _Nonnull const TWINME_KEYCHAIN_SERVICE = @"me.twin.twinme";

#ifdef TWINME
    //Prod
    static NSString * _Nonnull const SERVER_NAME = @"twin.me";
    static NSString * _Nonnull const SERVER_URL  = @"ws.twin.me";
    static NSString * _Nonnull const APP_GROUP_NAME = @"group.twinme.data";
    static NSString * _Nonnull const TWINME_APP_GROUP_NAME = @"group.twinme.data";
    static NSString * _Nonnull const KEYCHAIN_SERVICE = @"me.twin.twinme";
#elif defined(TWINME_PLUS)
    //Prod
    static NSString * _Nonnull const SERVER_NAME = @"twin.me";
    static NSString * _Nonnull const SERVER_URL  = @"ws.twin.me";
    static NSString * _Nonnull const APP_GROUP_NAME = @"group.twinme-plus.data";
    static NSString * _Nonnull const TWINME_APP_GROUP_NAME = @"group.twinme.data";
    static NSString * _Nonnull const KEYCHAIN_SERVICE = @"me.twin.twinme-plus";
#elif defined(MYTWINLIFE)
    static NSString * _Nonnull const SERVER_NAME = @"mytwinlife.net";
    static NSString * _Nonnull const SERVER_URL  = @"ws.mytwinlife.net";
    static NSString * _Nonnull const APP_GROUP_NAME = @"group.twinme-dev.data";
    static NSString * _Nonnull const TWINME_APP_GROUP_NAME = @"group.twinme-dev.data";
    static NSString * _Nonnull const KEYCHAIN_SERVICE = @"me.twin.twinme";
#elif defined(MYTWINLIFE_PLUS)
    static NSString * _Nonnull const SERVER_NAME = @"mytwinlife.net";
    static NSString * _Nonnull const SERVER_URL  = @"ws.mytwinlife.net";
    static NSString * _Nonnull const APP_GROUP_NAME = @"group.twinme-plus-dev.data";
    static NSString * _Nonnull const TWINME_APP_GROUP_NAME = @"group.twinme-dev.data";
    static NSString * _Nonnull const KEYCHAIN_SERVICE = @"me.twin.twinme-plus";
#endif

#endif

// Darwin notification messages for app and NotificationServiceExtension
#ifdef DEBUG
# define TL_NOTIFY_POSTFIX ".debug"
#else
# define TL_NOTIFY_POSTFIX
#endif

#ifdef SKRED
# define TL_NOTIFY_PREFIX "mobi.skred.notify"
#elif defined(TWINME)
# define TL_NOTIFY_PREFIX "me.twin.twinme"
#elif defined(TWINME_PLUS)
# define TL_NOTIFY_PREFIX "me.twin.twinme-plus"
#elif defined(MYTWINLIFE)
# define TL_NOTIFY_PREFIX "me.twin.mytwinlife"
#elif defined(MYTWINLIFE_PLUS)
# define TL_NOTIFY_PREFIX "me.twin.mytwinlife-plus"
#endif

#define TL_NOTIFY_APP_FOREGROUND CFSTR(TL_NOTIFY_PREFIX ".foreground" TL_NOTIFY_POSTFIX)
#define TL_NOTIFY_APP_BACKGROUND CFSTR(TL_NOTIFY_PREFIX ".background" TL_NOTIFY_POSTFIX)
#define TL_NOTIFY_APNS           CFSTR(TL_NOTIFY_PREFIX ".apns" TL_NOTIFY_POSTFIX)

#ifdef DEBUG
# define TL_DECL_MEASURE(VAR) int64_t (VAR) = 0;
# define TL_START_MEASURE(VAR)          \
  do {                                  \
    if ((VAR) == 0) {                   \
      (VAR) = [TLTwinlife timestamp];   \
    }                                   \
  } while (0);
# define TL_DECL_START_MEASURE(VAR) int64_t (VAR) = 0; TL_START_MEASURE(VAR);
# define TL_END_MEASURE(VAR, TITLE)                             \
  do {                                                          \
     [TLTwinlife perfReportWithTitle:(TITLE) startTime:(VAR)];  \
     (VAR) = 0;                                                 \
  } while (0);
#else
# define TL_DECL_MEASURE(VAR)
# define TL_START_MEASURE(VAR)
# define TL_DECL_START_MEASURE(VAR)
# define TL_END_MEASURE(VAR, TITLE)
#endif

//
// Interface: TLTwinlifeConfiguration
//

@protocol TLApplication;
@protocol TLRepositoryObjectFactory;
@class TLDeviceInfo;
@class TLSerializer;
@class TLServiceStats;
@class TLAccountServiceConfiguration;
@class TLConnectivityServiceConfiguration;
@class TLConversationServiceConfiguration;
@class TLCryptoServiceConfiguration;
@class TLManagementServiceConfiguration;
@class TLNotificationServiceConfiguration;
@class TLPeerConnectionServiceConfiguration;
@class TLRepositoryServiceConfiguration;
@class TLTwincodeFactoryServiceConfiguration;
@class TLTwincodeInboundServiceConfiguration;
@class TLTwincodeOutboundServiceConfiguration;
@class TLImageServiceConfiguration;
@class TLPeerCallServiceConfiguration;
@class TLAccountMigrationServiceConfiguration;
@class TLProxyDescriptor;

@interface TLTwinlifeConfiguration:NSObject

@property (readonly, nonnull) NSUUID *serviceId;
@property (readonly, nonnull) NSUUID *applicationId;
@property (readonly, nonnull) NSString *applicationName;
@property (readonly, nonnull) NSString *applicationVersion;
@property (readonly, nonnull) NSArray<TLSerializer *> *serializers;
@property (readonly, nonnull) NSArray<id<TLRepositoryObjectFactory>> *factories;
@property (readonly) BOOL enableSetup;
@property (readonly) BOOL enableCaches;
@property (readonly, nonnull) NSArray<TLProxyDescriptor *> *proxies;
@property (readonly, nonnull) NSArray<NSString *> *tokens;
@property (readonly, nonnull) NSString *apiKey;

@property (nonnull) TLAccountServiceConfiguration *accountServiceConfiguration;
@property (nonnull) TLConnectivityServiceConfiguration *connectivityServiceConfiguration;
@property (nonnull) TLConversationServiceConfiguration *conversationServiceConfiguration;
@property (nonnull) TLCryptoServiceConfiguration *cryptoServiceConfiguration;
@property (nonnull) TLManagementServiceConfiguration *managementServiceConfiguration;
@property (nonnull) TLNotificationServiceConfiguration *notificationServiceConfiguration;
@property (nonnull) TLPeerConnectionServiceConfiguration *peerConnectionServiceConfiguration;
@property (nonnull) TLRepositoryServiceConfiguration *repositoryServiceConfiguration;
@property (nonnull) TLTwincodeFactoryServiceConfiguration *twincodeFactoryServiceConfiguration;
@property (nonnull) TLTwincodeInboundServiceConfiguration *twincodeInboundServiceConfiguration;
@property (nonnull) TLTwincodeOutboundServiceConfiguration *twincodeOutboundServiceConfiguration;
@property (nonnull) TLImageServiceConfiguration *imageServiceConfiguration;
@property (nonnull) TLPeerCallServiceConfiguration *peerCallServiceConfiguration;
@property (nonnull) TLAccountMigrationServiceConfiguration *accountMigrationServiceConfiguration;

- (nonnull instancetype)initWithName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion serializers:(nonnull NSArray<TLSerializer *> *)serializers enableSetup:(BOOL)enableSetup enableCaches:(BOOL)enableCaches factories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories;

@end

//
// Interface: TLTwinlife
//

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
@class TLCryptoService;
@class TLAssertPoint;

@interface TLTwinlife : NSObject

@property (readonly, nonnull) dispatch_queue_t twinlifeQueue;

+ (void)dispose;

+ (nonnull NSString *)TWINLIFE_DOMAIN;

+ (nonnull NSString *)VERSION;

+ (nonnull NSString *)APP_GROUP_NAME;

+ (nonnull NSUserDefaults *)getAppSharedUserDefaults;

- (TLBaseServiceErrorCode)configure:(nonnull TLTwinlifeConfiguration *)twinlifeConfiguration;

- (TLTwinlifeStatus)status;

- (BOOL)isConfigured;

- (BOOL)isDatabaseUpgraded;

- (void)stopWithCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler;

- (void)applicationDidEnterBackground:(nullable id<TLApplication>)application;

- (void)applicationDidBecomeActive:(nullable id<TLApplication>)application;

/// When the ShareExtension creates a new operation to share some content, we have to re-load the conversation operations
/// and the ShareExtension is calling us through the openURL.
- (void)applicationDidOpenURL;

- (nonnull TLAccountService *)getAccountService;

- (nonnull TLConversationService *)getConversationService;

- (nonnull TLConnectivityService *)getConnectivityService;

- (nonnull TLManagementService *)getManagementService;

- (nonnull TLNotificationService *)getNotificationService;

- (nonnull TLPeerConnectionService *)getPeerConnectionService;

- (nonnull TLRepositoryService *)getRepositoryService;

- (nonnull TLTwincodeFactoryService *)getTwincodeFactoryService;

- (nonnull TLTwincodeInboundService *)getTwincodeInboundService;

- (nonnull TLTwincodeOutboundService *)getTwincodeOutboundService;

- (nonnull TLImageService *)getImageService;

- (nonnull TLPeerCallService *)getPeerCallService;

- (nonnull TLJobService *)getJobService;

- (nonnull TLAccountMigrationService *)getAccountMigrationService;

- (nonnull TLCryptoService *)getCryptoService;

- (nonnull NSDictionary<NSString *, TLServiceStats *> *)getServiceStats;

- (nonnull TLDeviceInfo *)getDeviceInfo;

+ (int64_t)timestamp;

+ (void)perfReportWithTitle:(nonnull NSString *)title startTime:(int64_t)startTime;

@end
