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

#include <sys/sysctl.h>
#include <stdatomic.h>
#include <mach/mach_time.h>

#define SQLITE_HAS_CODEC // Get access to the sqlite3_key() function.
#import <sqlite3.h>

#import <CocoaLumberjack.h>

#import <FMDatabase.h>
#import <FMDatabaseQueue.h>
#import <FMDatabaseAdditions.h>

#import "TLTwinlifeImpl.h"

#import "TLKeyChain.h"
#import "TLDatabaseService.h"
#import "TLTwinlifeSecuredConfiguration.h"
#import "TLProxyDescriptor.h"
#import "TLBaseServiceImpl.h"
#import "TLAccountServiceImpl.h"
#import "TLConnectivityServiceImpl.h"
#import "TLConversationServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLNotificationServiceImpl.h"
#import "TLPeerConnectionServiceImpl.h"
#import "TLRepositoryServiceImpl.h"
#import "TLTwincodeFactoryServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLImageServiceImpl.h"
#import "TLPeerCallServiceImpl.h"
#import "TLSerializerFactoryImpl.h"
#import "TLJobServiceImpl.h"
#import "TLDeviceInfo.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLBinaryPacketIQ.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLTwinlifeContext.h"
#import "TLAccountServiceSecuredConfiguration.h"
#import "TLDatabaseService.h"
#import "TLAccountMigrationServiceImpl.h"

#if 0
// static const int ddLogLevel = DDLogLevelVerbose;
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CIPHER_V3_DATABASE_NAME @"twinlife.cipher"
#define CIPHER_V4_DATABASE_NAME @"twinlife-4.cipher"

#if defined(DEBUG) && DEBUG == 1
# define EXPORT_DIR                     @"export"
# define IMPORT_DIR                     @"import"
# define CIPHER_V4_EXPORT_DATABASE_NAME @"twinlife-4-export.cipher"
# define CIPHER_V5_EXPORT_DATABASE_NAME @"twinlife-5-export.cipher"
# define EXPORT_ACCOUNT_CONFIGURATION   @"account-config.dat"
# define EXPORT_TWINLIFE_CONFIGURATION  @"twinlife-config.dat"
#endif

#define ON_ERROR_SCHEMA_ID @"12f8b46b-89fa-4b15-b3a3-946bc3abbb65"

/**
 * <pre>
 * Database Version 25
 *  Date: 2024/10/14
 *   Fix twincodeOutbound flags after introduction of beta support for SDPs encryption keys (internal version).
 *   Fix conversation table that could contain incorrect peerTwincodeOutbound for contact.
 *
 * Database Version 24
 *  Date: 2024/10/10
 *   Fix twincodeOutbound table which contains invalid `pair::twincodeOutboundId` due to a bug in TwincodeInboundService.
 *
 * Database Version 23
 *  Date: 2024/09/27
 *   New database model with twincodeKeys and secretKeys table
 *
 * Database Version 22:
 *  Date: 2024/07/19
 *   Fix bad mapping between Android and iOS for TLImageStatusTypeOwner and TLImageStatusTypeLocale
 *
 * Database Version 21
 *  Date: 2024/05/07
 *    Add columns creationDate and notificationId in the annotation table to record who annotates for the notification.
 *
 * Database Version 20
 *  Date: 2023/08/28
 *    New database schema optimized to allow loading repository objects and twincodes in a single SQL query.
 *
 * Database Version 14
 *  Date: 2022/12/07
 *   Repair the inconsistency in repositoryObject table in the key column that is sometimes null
 *
 * Database Version 13
 *  Date: 2022/02/25
 *
 *  ConversationService
 *   Update oldVersion [10]:
 *    Add table conversationDescriptorAnnotation
 *
 * Database Version 12:
 *  Date: 2020/12/07:
 *   No change but trigger a join group in the ConversationService for each group and to each group member.
 *
 * Database Version 11
 *  Date: 2020/06/24:
 *   Update oldVersion [6,10]:
 *    Add column 'timestamp INTEGER' in table notificationNotification
 *    Add column 'acknowledge INTEGER' in table notificationNotification
 *    Add column 'originatorId TEXT' in table notificationNotification
 *
 * Database Version 10
 *  Date: 2020/06/18:
 *   Update oldVersion [6,9]:
 *    Add column 'lock INTEGER' in table conversationConversation
 *    Add column 'lastConnectDate INTEGER' in table conversationConversation
 *    Add column 'groupId INTEGER' in table conversationConversation
 *    Add column 'cid INTEGER' in table conversationOperation
 *
 * Database Version 9
 *  Date: 2020/05/25
 *
 *  ImageService
 *   Update oldVersion [0,9]:
 *    Create table TwincodeImage
 *
 *  TwincodeOutboundService
 *   Update oldVersion [3,8]:
 *    Add column refreshPeriod INTEGER in  twincodeOutboundTwincodeOutbound
 *    Add column refreshDate INTEGER in  twincodeOutboundTwincodeOutbound
 *    Add column refreshTimestamp INTEGER in  twincodeOutboundTwincodeOutbound
 *   Update oldVersion [0,1]: reset
 *
 * Database Version 8
 *  Date: 2020/02/07
 *
 *  ConversationService
 *   Update oldVersion [6,7]:
 *    Add column 'createdTimestamp INTEGER' in table conversationDescriptor
 *    Add column 'cid INTEGER' in table conversationDescriptor
 *    Add column 'descriptorType INTEGER' in table conversationDescriptor
 *    Add column 'cid INTEGER' in table conversationConversation
 *   Update oldVersion [4,5]: -
 *   Update oldVersion [3]:
 *    Rename conversationObject table: conversationDescriptor
 *    Delete digest column from conversationDescriptor table
 *   Update oldVersion [0,2]: reset
 *
 * Database Version 7
 *  Date: 2019/01/17
 *
 *  RepositoryService
 *   Update oldVersion [2,6]:
 *    Add column stats BLOB in  repositoryObject
 *    Add column schemaId TEXT in repositoryObject
 *   Update oldVersion [0,1]: reset
 *
 * Database Version 6
 *  Date: 2017/04/27
 *
 *  ConversationService
 *   Update oldVersion == 4: -
 *   Update oldVersion <= 3: reset
 *  DirectoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  NotificationService
 *   Update oldVersion <= 5: reset
 *  RepositoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeFactoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeInboundService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeOutboundService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeSwitchService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *
 * Database Version 5
 *  Date: 2017/04/20
 *
 *  ConversationService
 *   Update oldVersion == 4: -
 *   Update oldVersion <= 3: reset
 *  DirectoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  NotificationService
 *  RepositoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeFactoryService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeInboundService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeOutboundService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *  TwincodeSwitchService
 *   Update oldVersion == [3,4]: -
 *   Update oldVersion <= 2: reset
 *
 * Database Version 4
 *  Date: 2016/10/10
 *
 *  ConversationService
 *   Update oldVersion <= 3: reset
 *  DirectoryService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *  RepositoryService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *  TwincodeFactoryService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *  TwincodeInboundService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *  TwincodeOutboundService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *  TwincodeSwitchService
 *   Update oldVersion == 3: -
 *   Update oldVersion <= 2: reset
 *
 * Database Version 3
 *  Date: 2015/11/28
 *
 *  ConversationService
 *   Update oldVersion <= 2: reset
 *  DirectoryService
 *   Update oldVersion == 2: -
 *   Update oldVersion <= 1: reset
 *  RepositoryService
 *   Update oldVersion == 2: -
 *   Update oldVersion <= 1: reset
 *  TwincodeFactoryService
 *   Update oldVersion == 2: -
 *   Update oldVersion <= 1: reset
 *  TwincodeInboundService
 *   Update oldVersion == 2: -
 *   Update oldVersion <= 1: reset
 *  TwincodeOutboundService
 *   Update oldVersion == 2: -
 *   Update oldVersion <= 2: reset
 *  TwincodeSwitchService
 *   Update oldVersion == 1: -
 *   Update oldVersion <= 1: reset
 *
 * </pre>
 */

#define DATABASE_VERSION 25

static NSTimeInterval MIN_DISCONNECTED_TIMEOUT = 16; // s
static NSTimeInterval MAX_DISCONNECTED_TIMEOUT = 512; // s
//static NSTimeInterval MIN_CONNECTED_TIMEOUT = 64; // s
//static NSTimeInterval NO_RECONNECTION_TIMEOUT = 0; // s
static NSTimeInterval MIN_RECONNECTION_TIMEOUT = 1; // s
//static NSTimeInterval MAX_RECONNECTION_TIMEOUT = 8; // s
//static NSTimeInterval CONNECTING_TIMEOUT = 10; // s

static TLTwinlife *sharedTwinlife;
static atomic_ullong requestId;
static TLBinaryPacketIQSerializer *IQ_ON_ERROR_SERIALIZER_INSTANCE = nil;

//
// Implementation: TLDeviceInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLDeviceInfo"

@implementation TLDeviceInfo

- (nonnull instancetype)initWithForegroundTime:(int64_t)foregroundTime backgroundTime:(int64_t)backgroundTime pushCount:(int)pushCount alarmCount:(int)alarmCount networkLockCount:(int)networkLockCount allowNotifications:(BOOL)allowNotifications {
    DDLogVerbose(@"%@ initWithForegroundTime", LOG_TAG);

    self = [super init];
    if (self) {
        _foregroundTime = foregroundTime;
        _backgroundTime = backgroundTime;
        _pushCount = pushCount;
        _alarmCount = alarmCount;
        _networkLockCount = networkLockCount;
        _allowNotifications = allowNotifications;

        UIDevice *myDevice = [UIDevice currentDevice];
        [myDevice setBatteryMonitoringEnabled:YES];

        _batteryLevel = (float)[myDevice batteryLevel] * 100;
        UIDeviceBatteryState state = [myDevice batteryState];
        _charging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
    }
    return self;
}

- (BOOL)isLowPowerModeEnabled {
    DDLogVerbose(@"%@ isLowPowerModeEnabled", LOG_TAG);

    return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
}

@end

//
// Implementation: TLTwinlifeConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeConfiguration"

@implementation TLTwinlifeConfiguration

- (instancetype)initWithName:(NSString *)applicationName applicationVersion:(NSString *)applicationVersion serializers:(NSArray<TLSerializer *> *)serializers enableSetup:(BOOL)enableSetup enableCaches:(BOOL)enableCaches factories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories {
    DDLogVerbose(@"%@ initWithName: %@ applicationVersion: %@ serializers: %@ enableSetup: %d enableCaches: %d", LOG_TAG, applicationName, applicationVersion, serializers, enableSetup, enableCaches);
    
    self = [super init];
    
    if (self) {
        _applicationName = applicationName;
        _applicationVersion = applicationVersion;
        _serializers = serializers;
        _enableSetup = enableSetup;
        _enableCaches = enableCaches;
        _factories = factories;
        _accountServiceConfiguration = [[TLAccountServiceConfiguration alloc] init];
        _connectivityServiceConfiguration = [[TLConnectivityServiceConfiguration alloc] init];
        _conversationServiceConfiguration = [[TLConversationServiceConfiguration alloc] init];
        _cryptoServiceConfiguration = [[TLCryptoServiceConfiguration alloc] init];
        _managementServiceConfiguration = [[TLManagementServiceConfiguration alloc] init];
        _notificationServiceConfiguration = [[TLNotificationServiceConfiguration alloc] init];
        _peerConnectionServiceConfiguration = [[TLPeerConnectionServiceConfiguration alloc] init];
        _repositoryServiceConfiguration = [[TLRepositoryServiceConfiguration alloc] init];
        _twincodeFactoryServiceConfiguration = [[TLTwincodeFactoryServiceConfiguration alloc] init];
        _twincodeInboundServiceConfiguration = [[TLTwincodeInboundServiceConfiguration alloc] init];
        _twincodeOutboundServiceConfiguration = [[TLTwincodeOutboundServiceConfiguration alloc] init];
        _imageServiceConfiguration = [[TLImageServiceConfiguration alloc] init];
        _peerCallServiceConfiguration = [[TLPeerCallServiceConfiguration alloc] init];
        _accountMigrationServiceConfiguration = [[TLAccountMigrationServiceConfiguration alloc] init];

        NSString* path = [[NSBundle mainBundle] pathForResource:@"tool" ofType:@"cfg"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        data = [TLKeyChain decryptWithData:data];
        if (!data) {
            DDLogError(@"%@ invalid application configuration %@", LOG_TAG, path);
#if defined(DEBUG) && DEBUG == 1
            DDLogError(@"%@ the configuration file 'Twinme/Resources/<app>/tool.cfg' is probably missing or cannot be loaded", LOG_TAG);
#endif
            return self;
        }
        TLBinaryDecoder *binaryDecoder = [[TLBinaryCompactDecoder alloc] initWithData:data];
        _applicationId = [binaryDecoder readUUID];
        _serviceId = [binaryDecoder readUUID];
        _apiKey = [binaryDecoder readString];
        int keyProxyCount = [binaryDecoder readInt];
        int sniProxyCount = [binaryDecoder readInt];
        NSMutableArray<TLProxyDescriptor *> *proxies = [[NSMutableArray alloc] initWithCapacity:keyProxyCount + sniProxyCount];
        for (int i = 0; i < keyProxyCount; i++) {
            int port = [binaryDecoder readInt];
            int stunPort = [binaryDecoder readInt];
            NSString *address = [binaryDecoder readIP];
            NSString *key = [binaryDecoder readString];
            [proxies addObject:[[TLKeyProxyDescriptor alloc] initWithAddress:address port:port stunPort:stunPort key:key]];
        }
        for (int i = 0; i < sniProxyCount; i++) {
            int port = [binaryDecoder readInt];
            int stunPort = [binaryDecoder readInt];
            NSString *address = [binaryDecoder readIP];
            [proxies addObject:[[TLSNIProxyDescriptor alloc] initWithHost:address port:port stunPort:stunPort isUserProxy:NO]];
        }
        _proxies = proxies;

        int tokenCount = [binaryDecoder readInt];
        NSMutableArray<NSString *> *tokens = [[NSMutableArray alloc] initWithCapacity:tokenCount];
        for (int i = 0; i < tokenCount; i++) {
            [tokens addObject:[binaryDecoder readString]];
        }
        _tokens = tokens;
    }
    return self;
}

@end

//
// Implementation: TLConnectionMonitor
//

#undef LOG_TAG
#define LOG_TAG @"TLConnectionMonitor"

@implementation TLConnectionMonitor

- (nonnull instancetype)init {
    
    self = [super init];
    _running = YES;
    return self;
}

@end

//
// Implementation: TLTwinlife
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinlife"

@implementation TLTwinlife

+ (void)initialize {
    DDLogVerbose(@"%@ initialize", LOG_TAG);
    
    sharedTwinlife = [[TLTwinlife alloc] init];
    requestId = 0L;

    IQ_ON_ERROR_SERIALIZER_INSTANCE = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_ERROR_SCHEMA_ID schemaVersion:1];
}

+ (TLTwinlife *)sharedTwinlife {
    DDLogVerbose(@"%@ sharedTwinlife", LOG_TAG);
    
    return sharedTwinlife;
}

+ (int64_t)newRequestId {
    DDLogVerbose(@"%@ newRequestId", LOG_TAG);
    
    return atomic_fetch_add(&requestId, 1);
}

+ (BOOL)MANAGEMENT_REPORT_IOS_ID {
    DDLogVerbose(@"%@ MANAGEMENT_REPORT_IOS_ID", LOG_TAG);
    
    #ifdef SKRED
        return YES;
    #else
        return NO;
    #endif
}

+ (nullable NSURL *)getAppGroupURL:(nonnull NSFileManager *)fileManager {
    DDLogVerbose(@"%@ getAppGroupURL: %@", LOG_TAG, fileManager);

    NSURL *groupURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME];
    if (!groupURL) {
        DDLogError(@"%@ iOS AppGroup does not exist", LOG_TAG);
    }

    return groupURL;
}

+ (nonnull NSString *)getAppGroupPath:(nonnull NSFileManager *)fileManager path:(nonnull NSString *)path {
    DDLogVerbose(@"%@ getAppGroupPath: %@ path: %@", LOG_TAG, fileManager, path);

    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
    NSURL *url = [groupURL URLByAppendingPathComponent:path];

    return url.path;
}

+ (NSUserDefaults *)getAppSharedUserDefaults {

    return [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_NAME];
}

+ (NSUserDefaults *)getAppSharedUserDefaultsWithAlternateApplication:(BOOL)alternateApplication {

    return [[NSUserDefaults alloc] initWithSuiteName:alternateApplication ? TWINME_APP_GROUP_NAME : APP_GROUP_NAME];
}

+ (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);

    // Disconnect and close the database to avoid having an opened file lock on the database.
    if (sharedTwinlife) {
        [sharedTwinlife disconnect];
        [sharedTwinlife.databaseQueue close];
    }
    sharedTwinlife = nil;
}

+ (NSString *)TWINLIFE_DOMAIN {
    
    return SERVER_NAME;
}

+ (NSString *)VERSION {
    
    return TWINLIFE_VERSION;
}

+ (nonnull NSString *)APP_GROUP_NAME {
    
    #ifdef SKRED
        return TWINME_APP_GROUP_NAME;
    #else
        return APP_GROUP_NAME;
    #endif
}

+ (nonnull TLBinaryPacketIQSerializer *)IQ_ON_ERROR_SERIALIZER {
    
    return IQ_ON_ERROR_SERIALIZER_INSTANCE;
}

- (id)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    if (self = [super init]) {
        _serializerFactory = [[TLSerializerFactory alloc] init];
        _binaryPacketListeners = [[NSMutableDictionary alloc] init];
        _jobService = [[TLJobService alloc] initWithTwinlife:self];
        _databaseService = [[TLDatabaseService alloc] initWithTwinlife:self];
        _accountService = [[TLAccountService alloc] initWithTwinlife:self];
        _connectivityService = [[TLConnectivityService alloc] initWithTwinlife:self];
        _cryptoService = [[TLCryptoService alloc] initWithTwinlife:self];
        _managementService = [[TLManagementService alloc] initWithTwinlife:self];
        _imageService = [[TLImageService alloc] initWithTwinlife:self];
        _twincodeFactoryService = [[TLTwincodeFactoryService alloc] initWithTwinlife:self];
        _twincodeInboundService = [[TLTwincodeInboundService alloc] initWithTwinlife:self];
        _twincodeOutboundService = [[TLTwincodeOutboundService alloc] initWithTwinlife:self];
        _repositoryService = [[TLRepositoryService alloc] initWithTwinlife:self];
        _notificationService = [[TLNotificationService alloc] initWithTwinlife:self];
        _peerCallService = [[TLPeerCallService alloc] initWithTwinlife:self];
        _peerConnectionService = [[TLPeerConnectionService alloc] initWithTwinlife:self];
        _conversationService = [[TLConversationService alloc] initWithTwinlife:self peerConnectionService:_peerConnectionService];
        _accountMigrationService = [[TLAccountMigrationService alloc] initWithTwinlife:self];
        //
        // AccountService should be the last service to call onConnect before onSignIn
        // in all services
        //
        _twinlifeServices = @[_connectivityService,
                              _conversationService,
                              _managementService,
                              _notificationService,
                              _peerCallService,
                              _peerConnectionService,
                              _repositoryService,
                              _twincodeFactoryService,
                              _twincodeInboundService,
                              _twincodeOutboundService,
                              _imageService,
                              _accountMigrationService,
                              _accountService
                              ];

        const char *twinlifeQueueName = "twinlifeQueue";
        _twinlifeQueue = dispatch_queue_create(twinlifeQueueName, DISPATCH_QUEUE_SERIAL);
        _twinlifeQueueTag = &_twinlifeQueueTag;
        dispatch_queue_set_specific(_twinlifeQueue, _twinlifeQueueTag, _twinlifeQueueTag, NULL);

        _serverQueueTag = &_serverQueueTag;
        _serverQueue = dispatch_queue_create("serverTwinlifeQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_serverQueue, _serverQueueTag, _serverQueueTag, NULL);

        _model = [self getModel];
        //_connectionRetries = 0;
        //_connectedTimeout = MIN_CONNECTED_TIMEOUT;
        //_connectingCondition = [[NSCondition alloc] init];
        //_connectingTimeout = CONNECTING_TIMEOUT;
        _inBackground = YES;
        _databaseUpgraded = NO;
        _databaseVersion = 0;
        _twinlifeStatus = TLTwinlifeStatusUninitialized;
        _forceApplicationRestart = NO;

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
        NSURL *path = [groupURL URLByAppendingPathComponent:@"twinlife-connect.lock"];
        _connectLockFile = path.path;
        _connectLockFd = -1;
        _darwinNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter();
    }
    return self;
}

#pragma mark - TLTwinlife

- (TLBaseServiceErrorCode)configure:(TLTwinlifeConfiguration *)twinlifeConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, twinlifeConfiguration);
    
    NSUUID *applicationId = twinlifeConfiguration.applicationId;
    NSUUID *serviceId = twinlifeConfiguration.serviceId;
    if (!serviceId || !applicationId || !twinlifeConfiguration.applicationName || !twinlifeConfiguration.applicationVersion || !self.connectLockFile) {
        self.configured = NO;
        atomic_store(&_twinlifeStatus, TLTwinlifeStatusError);
        return TLBaseServiceErrorCodeWrongLibraryConfiguration;
    }

    [TLKeyChain waitUntilReady];

#if defined(DEBUG) && DEBUG == 1
    // For development only, before loading the secure configuration and anything else,
    // check for the import directory to replace the current configuration by the imported one.
    // The import directory is then removed so that the import is done only once.
    [self developmentExportInternalFiles];
    [self developmentImportExternalFiles];
#endif

    // Finish a possible migration that was successfully finished but which was not installed yet.
    // By installing it here, the secure configuration, account configuration and database are moved
    // before starting to use them.  If there is no migration, this is no-op.
    [self.accountMigrationService finishMigration];

    @synchronized(self) {
        self.configured = NO;
        self.twinlifeConfiguration = twinlifeConfiguration;

        // Load the application secure configuration.
        self.twinlifeSecuredConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:self.serializerFactory alternateApplication:NO];
        if (!self.twinlifeSecuredConfiguration || [self needInstall]) {
            if (!twinlifeConfiguration.enableSetup) {
                // We are an iOS extension and we must not create the configuration nor update it.
                DDLogError(@"%@ secure configuration not found and setup disabled", LOG_TAG);
                atomic_store(&_twinlifeStatus, TLTwinlifeStatusError);
                return TLBaseServiceErrorCodeWrongLibraryConfiguration;
            }

#ifndef TWINME_PLUS
            // Create the new secure configuration
            self.twinlifeSecuredConfiguration = [[TLTwinlifeSecuredConfiguration alloc] initWithSerializerFactory:self.serializerFactory];
            if (!self.twinlifeSecuredConfiguration) {
                atomic_store(&_twinlifeStatus, TLTwinlifeStatusError);
                return TLBaseServiceErrorCodeLibraryError;
            }

            self.isInstalled = YES;
#else
            // Try to load the Twinme Lite secure configuration and move it to our app group and keychain.
            self.twinlifeSecuredConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:self.serializerFactory alternateApplication:YES];
            if (!self.twinlifeSecuredConfiguration) {
                // Create the new secure configuration.
                self.twinlifeSecuredConfiguration = [[TLTwinlifeSecuredConfiguration alloc] initWithSerializerFactory:self.serializerFactory];
                self.isInstalled = YES;

                // Import from Twinme Lite and if this fails, abort.
            } else if (![self importApplicationData]) {
                DDLogError(@"%@ failed to import application data", LOG_TAG);
                return TLBaseServiceErrorCodeLibraryError;
            }
#endif
        }

        self.resource = [NSString stringWithFormat:@"%@%@", self.model, self.twinlifeSecuredConfiguration.deviceIdentifier];
    }
    
    [self.serializerFactory addSerializers:twinlifeConfiguration.serializers];

    __weak TLTwinlife *twinlife = self;
    [self addPacketListener:IQ_ON_ERROR_SERIALIZER_INSTANCE listener:^(TLBinaryPacketIQ * iq) {
        __strong TLTwinlife *strongTwinlife = twinlife;
        if (strongTwinlife) {
            [strongTwinlife onGetErrorWithIQ:iq];
        }
    }];

    [self.cryptoService configure:twinlifeConfiguration.cryptoServiceConfiguration];
    self.twinlifeConfiguration.cryptoServiceConfiguration = (TLCryptoServiceConfiguration *)self.cryptoService.serviceConfiguration;
    
    [self.accountService configure:twinlifeConfiguration.accountServiceConfiguration applicationId:applicationId serviceId:serviceId];
    self.twinlifeConfiguration.accountServiceConfiguration = (TLAccountServiceConfiguration *)self.accountService.serviceConfiguration;
    
    [self.connectivityService configure:twinlifeConfiguration.connectivityServiceConfiguration];
    self.twinlifeConfiguration.connectivityServiceConfiguration = (TLConnectivityServiceConfiguration*)self.connectivityService.serviceConfiguration;

    [self.managementService configure:twinlifeConfiguration.managementServiceConfiguration applicationId:applicationId];
    self.twinlifeConfiguration.managementServiceConfiguration = (TLManagementServiceConfiguration *)self.managementService.serviceConfiguration;
    
    [self.imageService configure:twinlifeConfiguration.imageServiceConfiguration];
    self.twinlifeConfiguration.imageServiceConfiguration = (TLImageServiceConfiguration *)self.imageService.serviceConfiguration;

    [self.twincodeFactoryService configure:twinlifeConfiguration.twincodeFactoryServiceConfiguration];
    self.twinlifeConfiguration.twincodeFactoryServiceConfiguration = (TLTwincodeFactoryServiceConfiguration *)self.twincodeFactoryService.serviceConfiguration;
    
    [self.twincodeInboundService configure:twinlifeConfiguration.twincodeInboundServiceConfiguration];
    self.twinlifeConfiguration.twincodeInboundServiceConfiguration = (TLTwincodeInboundServiceConfiguration *)self.twincodeInboundService.serviceConfiguration;
    
    [self.twincodeOutboundService configure:twinlifeConfiguration.twincodeOutboundServiceConfiguration];
    self.twinlifeConfiguration.twincodeOutboundServiceConfiguration = (TLTwincodeOutboundServiceConfiguration *)self.twincodeOutboundService.serviceConfiguration;
    
    [self.repositoryService configure:twinlifeConfiguration.repositoryServiceConfiguration factories:twinlifeConfiguration.factories];
    self.twinlifeConfiguration.repositoryServiceConfiguration = (TLRepositoryServiceConfiguration *)self.repositoryService.serviceConfiguration;
    
    [self.notificationService configure:twinlifeConfiguration.notificationServiceConfiguration];
    self.twinlifeConfiguration.notificationServiceConfiguration = (TLNotificationServiceConfiguration *)self.notificationService.serviceConfiguration;

    [self.conversationService configure:twinlifeConfiguration.conversationServiceConfiguration];
    self.twinlifeConfiguration.conversationServiceConfiguration = (TLConversationServiceConfiguration*)self.conversationService.serviceConfiguration;

    [self.peerCallService configure:twinlifeConfiguration.peerCallServiceConfiguration];
    self.twinlifeConfiguration.peerCallServiceConfiguration = (TLPeerCallServiceConfiguration *)self.peerCallService.serviceConfiguration;
    
    [self.peerConnectionService configure:twinlifeConfiguration.peerConnectionServiceConfiguration];
    self.twinlifeConfiguration.peerConnectionServiceConfiguration = (TLPeerConnectionServiceConfiguration *)self.peerConnectionService.serviceConfiguration;

    [self.accountMigrationService configure:twinlifeConfiguration.accountMigrationServiceConfiguration];
    self.twinlifeConfiguration.accountMigrationServiceConfiguration = (TLAccountMigrationServiceConfiguration *) self.accountMigrationService.serviceConfiguration;
    
    self.configured = YES;
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            self.configured = self.configured && [service isConfigured];
        }
    }
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onCreate];
        }
    }
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onConfigure];
        }
    }
    
    // Open and check that the database was successfully opened.
    TLBaseServiceErrorCode result = [self openDatabase];
    if (result != TLBaseServiceErrorCodeSuccess) {
        self.configured = NO;
        atomic_store(&_twinlifeStatus, TLTwinlifeStatusError);
        return result;
    }
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onTwinlifeReady];
        }
    }
    
    atomic_store(&_twinlifeStatus, TLTwinlifeStatusConfigured);
    return TLBaseServiceErrorCodeSuccess;
}

#ifdef TWINME_PLUS
- (BOOL)importApplicationData {
    DDLogVerbose(@"%@ importApplicationData", LOG_TAG);

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSURL *groupURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME];
    if (!groupURL) {

        DDLogError(@"%@ importApplicationData: there is no App Group", LOG_TAG);
        return NO;
    }

    NSURL *twinmeGroupURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:TWINME_APP_GROUP_NAME];
    if (!twinmeGroupURL) {

        DDLogError(@"%@ importApplicationData: there is no alternate App Group to import", LOG_TAG);
        return NO;
    }

    if (![TLTwinlifeSecuredConfiguration importApplicationData]) {

        DDLogError(@"%@ importApplicationData: failed to import the secure configuration", LOG_TAG);
        return NO;
    }

    if (![TLAccountServiceSecuredConfiguration importApplicationData:self.serializerFactory]) {
        
        DDLogError(@"%@ importApplicationData: failed to import the account configuration", LOG_TAG);
        return NO;
    }

    // Move the Twinme Lite database to the current application.
    // Try with the V4 database path.
    NSURL *path = [twinmeGroupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
    if (path && [fileManager fileExistsAtPath:path.path]) {
        NSURL *targetPath = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
        NSError *error;
        
        DDLogInfo(@"%@ importApplicationData: import database file", LOG_TAG);
        
        [fileManager moveItemAtPath:path.path toPath:targetPath.path error:&error];
        if (error) {
            DDLogError(@"%@ importApplicationData: failed to move database: %@", LOG_TAG, error);
        }
    } else {
        // No V5 file, try with the V4 file.
        path = [twinmeGroupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
        if (path && [fileManager fileExistsAtPath:path.path]) {
            NSURL *targetPath = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
            NSError *error;
            
            DDLogInfo(@"%@ importApplicationData: import database file", LOG_TAG);
            
            [fileManager moveItemAtPath:path.path toPath:targetPath.path error:&error];
            if (error) {
                DDLogError(@"%@ importApplicationData: failed to move database: %@", LOG_TAG, error);
            }
        }
    }

    // Move the conversation files from Twinme Lite to the current application.
    path = [twinmeGroupURL URLByAppendingPathComponent:@"Conversations"];
    if (path && [fileManager fileExistsAtPath:path.path]) {
        NSURL *targetPath = [groupURL URLByAppendingPathComponent:@"Conversations"];

        DDLogInfo(@"%@ importApplicationData: import conversations files", LOG_TAG);
        NSError *error;
        
        [fileManager moveItemAtPath:path.path toPath:targetPath.path error:&error];
        if (error) {
            DDLogError(@"%@ importApplicationData: failed to import conversation files: %@", LOG_TAG, error);
        }
    }

    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_NAME];
    NSUserDefaults *twinmeUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:TWINME_APP_GROUP_NAME];

    // We need the environment id for the encryption key and it must be the same between the main app and its extension.
    id value = [twinmeUserDefaults objectForKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
    if (value) {
        [userDefaults setObject:value forKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
    }

    [userDefaults synchronize];

    return YES;
}
#endif

- (BOOL)isConfigured {
    DDLogVerbose(@"%@ isConfigured", LOG_TAG);
    
    return self.configured;
}

- (BOOL)isDatabaseUpgraded {
    DDLogVerbose(@"%@ isDatabaseUpgraded", LOG_TAG);
    
    return self.databaseUpgraded;
}

- (void)stopWithCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler {
    DDLogVerbose(@"%@ stopWithCompletionHandler", LOG_TAG);

    // Prepare to suspend the services: it will call twinlifeSuspend, disconnect.
    if (completionHandler) {
        [self.jobService suspendWithCompletionHandler:completionHandler];
    } else {
        [self.jobService suspend];
    }
}

- (void)applicationDidEnterBackground:(nullable id<TLApplication>)application {
    DDLogVerbose(@"%@ applicationDidEnterBackground: %@", LOG_TAG, application);

    self.inBackground = YES;
    [self.jobService onEnterBackgroundWithApplication:application];
}

- (void)applicationDidBecomeActive:(nullable id<TLApplication>)application {
    DDLogVerbose(@"%@ applicationDidBecomeActive: %@", LOG_TAG, application);

    self.inBackground = NO;
    [self.jobService onEnterForegroundWithApplication:application];
}

- (void)applicationDidOpenURL {
    DDLogVerbose(@"%@ applicationDidOpenURL", LOG_TAG);

    [self.conversationService reloadOperations];
}

- (TLAccountService *)getAccountService {
    
    return self.accountService;
}

- (TLConnectivityService *)getConnectivityService {
    
    return self.connectivityService;
}

- (TLConversationService *)getConversationService {
    
    return self.conversationService;
}

- (TLManagementService *)getManagementService {
    
    return self.managementService;
}

- (TLNotificationService *)getNotificationService {
    
    return self.notificationService;
}

- (TLPeerConnectionService *)getPeerConnectionService {
    
    return self.peerConnectionService;
}

- (TLRepositoryService *)getRepositoryService {
    
    return self.repositoryService;
}

- (TLTwincodeFactoryService *)getTwincodeFactoryService {
    
    return self.twincodeFactoryService;
}

- (TLTwincodeInboundService *)getTwincodeInboundService {
    
    return self.twincodeInboundService;
}

- (TLTwincodeOutboundService *)getTwincodeOutboundService {
    
    return self.twincodeOutboundService;
}

- (TLImageService *)getImageService {
    
    return self.imageService;
}

- (TLPeerCallService *)getPeerCallService {
    
    return self.peerCallService;
}

- (TLJobService *)getJobService {
    
    return self.jobService;
}

- (nonnull TLAccountMigrationService *)getAccountMigrationService {
    return self.accountMigrationService;
}

- (nonnull TLCryptoService *)getCryptoService {
    
    return self.cryptoService;
}

- (NSDictionary<NSString *, TLServiceStats *> *)getServiceStats {
    DDLogVerbose(@"%@ getServiceStats", LOG_TAG);

    NSMutableDictionary<NSString *, TLServiceStats *> *result = [[NSMutableDictionary alloc] init];
    for (TLBaseService *service in self.twinlifeServices) {
        result[[service getServiceName]] = [service getServiceStats];
    }
    return result;
}

- (TLDeviceInfo *)getDeviceInfo {
    DDLogVerbose(@"%@ getDeviceInfo", LOG_TAG);

    return [self.jobService getDeviceInfo];
}

- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint, ... NS_REQUIRES_NIL_TERMINATION {
    DDLogVerbose(@"%@ assertionWithAssertPoint: %@", LOG_TAG, assertPoint);

    va_list args;
    va_start(args, assertPoint);
    [self.managementService assertionWithAssertPoint:assertPoint exception:nil vaList:args];
    va_end(args);
}

- (void)exceptionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nonnull NSException *)exception, ... NS_REQUIRES_NIL_TERMINATION {
    DDLogVerbose(@"%@ exceptionWithAssertPoint: %@ exception: %@", LOG_TAG, assertPoint, exception);

    va_list args;
    va_start(args, exception);
    [self.managementService assertionWithAssertPoint:assertPoint exception:exception vaList:args];
    va_end(args);
}

- (nonnull NSString *)getDatabaseDiagnostic {
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:1024];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
    NSURL *path = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
    NSString *databasePath = path.path;

    if ([fileManager fileExistsAtPath:databasePath]) {
        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:databasePath error:nil];
        [result appendFormat:@"Database: %lld", [[attrs objectForKey:NSFileSize] longLongValue]];
    } else {
        [result appendString:@"Database: missing"];
    }
    if (self.databaseQueue) {
        [self.databaseService inDatabase:^(FMDatabase *database) {
            [result appendString:database ? @" opened" : @" db-closed"];
            [result appendFormat:@" %d", [database intForQuery:@"PRAGMA user_version"]];
            [result appendFormat:@" %ld", [database longForQuery:@"SELECT COUNT(*) FROM repository"]];
            [result appendFormat:@" %ld", [database longForQuery:@"SELECT COUNT(*) FROM twincodeOutbound"]];
            [result appendFormat:@" %ld", [database longForQuery:@"SELECT COUNT(*) FROM twincodeInbound"]];
        }];
    } else {
        [result appendString:@" closed"];
    }
    [result appendString:@"\n"];

    NSString *walPath = [NSString stringWithFormat:@"%@-wal", databasePath];
    if ([fileManager fileExistsAtPath:walPath]) {
        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:walPath error:nil];
        [result appendFormat:@"Database WAL: %lld\n", [[attrs objectForKey:NSFileSize] longLongValue]];
    }

    return result;
}

- (nonnull NSString *)getOpenedFileDiagnostic {
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:1024];
    int firstFd = -1;
    int lastFd = -1;

    [result appendString:@"OpenedFiles: "];
    for (int fd = 0; fd < 1024; fd++) {
        if (fcntl(fd, F_GETFD) != -1 && errno != EBADF) {
            if (firstFd < 0) {
                firstFd = fd;
            }
            lastFd = fd;
        } else if (firstFd >= 0) {
            if (firstFd == lastFd) {
                [result appendFormat:@" %d", firstFd];
            } else {
                [result appendFormat:@" %d..%d", firstFd, lastFd];
            }
            firstFd = -1;
            lastFd = -1;
        }
    }
    if (firstFd >= 0) {
        [result appendFormat:@" %d..%d", firstFd, lastFd];
    }
    [result appendString:@"\n"];
    return result;
}

+ (int64_t)timestamp {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ts.tv_sec * 1000000000LL) + ts.tv_nsec;
}

+ (void)perfReportWithTitle:(NSString *)title startTime:(int64_t)startTime {
    
    int64_t durationTime = [TLTwinlife timestamp] - startTime;
    int64_t usTime = durationTime / 1000LL;
    if (usTime > 1000000LL) {
        int64_t msTime = usTime / 1000LL;
        DDLogError(@"Execution time %@: %lld.%03lld s", title, msTime / 1000L, msTime % 1000L);
    } else {
        DDLogError(@"Execution time %@: %lld.%03lld ms", title, usTime / 1000L, usTime % 1000L);
    }
}

//
// TLTwinlifeImpl ()
//

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);

    TL_START_MEASURE(self.startTime)
    if (!self.serverConnection && self.twinlifeConfiguration.connectivityServiceConfiguration.serviceOn) {
        self.serverConnection = [[TLServerConnection alloc] initWithDomainName:SERVER_NAME serverURL:SERVER_URL delegate:self connectivityService:self.connectivityService twinlifeConfiguration:self.twinlifeConfiguration];

        for (TLBaseService *service in self.twinlifeServices) {
            if ([service isServiceOn]) {
                [service activate:self.serverConnection];
            }
        }
    }

    [self twinlifeResume];
} 

- (NSString *)getFullJid {
    DDLogVerbose(@"%@ getFullJid", LOG_TAG);
    
    return [self.accountService user];
}

- (TLTwinlifeStatus)status {
    DDLogVerbose(@"%@ status", LOG_TAG);

    return self.twinlifeStatus;
}

- (BOOL)isConnected {
    DDLogVerbose(@"%@ isConnected", LOG_TAG);
    
    return self.serverConnection && self.serverConnection.isOpened;
}

- (void)connect {
    DDLogVerbose(@"%@ connect", LOG_TAG);

    if (!self.serverConnection) {
        return;
    }

    [self twinlifeResume];

    self.serverConnection.reconnectionTime = 0;
    if (self.connectivityService) {
        [self.connectivityService signalAll];
    }
    [self.serverConnection triggerWorker];
}

- (void)disconnect {
    DDLogInfo(@"%@ disconnect connectionStatus: %d status: %d", LOG_TAG, [self.serverConnection connectionStatus], [self status]);

    [self unlockServerConnection];
    if ([self.serverConnection disconnect] && [self status] == TLTwinlifeStatusSuspending) {
        // If we are suspending, close the database to enter in the final TLTwinlifeStatusSuspended state.
        [self twinlifeSuspended];
    }
}

- (BOOL)isTwinlifeOnline {
    DDLogVerbose(@"%@ isTwinlifeOnline %d", LOG_TAG, self.online);
    
    // If we started to disconnect, we don't want to start any new conversation.
    // Also take the opportunity to verify the websocket connection.
    return self.online; // SCz && ![self isDisconnecting] && [self isConnected];
}

- (TLConnectionStatus)connectionStatus {
    DDLogVerbose(@"%@ connectionStatus %d", LOG_TAG, self.online);
    
    // We could return a StatusOnline which indicates that Authenticate phase succeeded.
    // if ([self isTwinlifeOnline]) {
    //    return TLConnectionStatusConnected;
    // }
    TLConnectionStatus status = [self.serverConnection connectionStatus];
    if (status != TLConnectionStatusNoService) {
        return status;
    }
    if (![self.connectivityService isConnectedNetwork]) {
        return TLConnectionStatusNoInternet;
    }
    if (self.connectionFailed) {
        return TLConnectionStatusNoService;
    }
    return TLConnectionStatusConnecting;
}

- (BOOL)isProcessActive:(int)lockIdentifier date:(int64_t)date {
    DDLogVerbose(@"%@ isProcessActive %d date: %lld", LOG_TAG, lockIdentifier, date);
    
    // If we have the connection lock, we can assume the other process is not active.
    if (self.connectLockFd >= 0) {
        return NO;
    }

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    return now < date + (45 * 1000L);
}

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener {
    DDLogVerbose(@"%@ addPacketListener: %@", LOG_TAG, serializer);

    TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
    self.binaryPacketListeners[key] = listener;
    [self.serializerFactory addSerializer:serializer];
}

- (void)onUpdateConfigurationWithConfiguration:(TLBaseServiceImplConfiguration *)configuration {
    DDLogVerbose(@"%@ onUpdateConfigurationWithConfiguration: %@", LOG_TAG, configuration);
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onUpdateConfigurationWithConfiguration:configuration];
        }
    }
}

- (void)adjustTimeWithServerTime:(int64_t)serverTime deviceTime:(int64_t)deviceTime serverLatency:(int)serverLatency requestTime:(int64_t)requestTime {
    
    // Compute the propagation time: RTT (ignore excessive values).
    int64_t tp = (requestTime - serverLatency);
    if (tp < 0 || tp > 60000 || serverLatency < 0) {
        self.serverTimeCorrection = 0;
        self.estimatedRTT = 0;
        return;
    }

    // Compute the time correction (note: deviceTime is the time when we received the
    // server response it is ahead of tp/2 compared to the server time).
    int64_t tc = (serverTime - (deviceTime - (tp / 2)));

    self.serverTimeCorrection = -tc;
    self.estimatedRTT = (int)tp;
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.online = YES;
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onTwinlifeOnline];
        }
    }
}

- (void)twinlifeSuspend {
    DDLogVerbose(@"%@ twinlifeSuspend", LOG_TAG);
    
    // If a connection monitor is running, stop it.
    TL_START_MEASURE(self.startSuspendTime)
    self.isInstalled = NO;
    
    // The job service is suspending, switch to suspending state so that
    // the services will avoid starting/accepting new P2P connections.
    TLTwinlifeStatus status = [self status];
    if (status == TLTwinlifeStatusStarted || status == TLTwinlifeStatusConfigured) {
        atomic_store(&_twinlifeStatus, TLTwinlifeStatusSuspending);
    }
    if (self.forceApplicationRestart) {
        DDLogError(@"%@ application data was migrated, restarting", LOG_TAG);
        @throw [NSException exceptionWithName:@"TLApplicationRestart" reason:@"Application data was migrated" userInfo:nil];
    }
    
    // Keep the date when we are suspended: we will need to reload some objects.
    self.lastSuspendDate = [[NSDate date] timeIntervalSince1970] * 1000;
    
    if (self.twinlifeSuspendObserver) {
        [self.twinlifeSuspendObserver onTwinlifeSuspend];
    }
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onTwinlifeSuspend];
        }
    }
    
    // If a connection monitor is running, stop it.
    @synchronized (self) {
        if (self.connectionMonitor) {
            self.connectionMonitor.running = NO;
            self.connectionMonitor = nil;
        }
    }
    [self.serverConnection triggerWorker];

    // Note: the call to disconnect must not be done now but later, if we are still connected
    // it is fine, what is necessary is to release the monitor's thread and release the network
    // connection lock earlier.
    [self unlockServerConnection];
    
    int64_t suspendTime = self.startSuspendTime;
    TL_END_MEASURE(suspendTime, @"twinlifeSuspend");
}

- (BOOL)twinlifeSuspended {
    DDLogVerbose(@"%@ twinlifeSuspended", LOG_TAG);

    // Check that we are suspending before closing the database.
    // It is possible that the call to twinlifeSuspended was queued within the twinlifeQueue
    // and it is being executed after suspension when the application resumes!
    int status = TLTwinlifeStatusSuspending;
    if (atomic_compare_exchange_strong(&_twinlifeStatus, &status, TLTwinlifeStatusSuspended)) {
        [self closeDatabase];
        
        TL_END_MEASURE(self.startSuspendTime, @"twinlifeSuspended");
        self.startTime = 0;
        
        // Tell the job service we are now suspended: it can release the shutdown job.
        return [self.jobService onTwinlifeSuspended];
    } else {
        // Check if suspension was done.
        return status == TLTwinlifeStatusSuspended;
    }
}

static void darwinNotificationObserver(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {

    TLTwinlife *twinlifeImpl = (__bridge TLTwinlife *)observer;
    [twinlifeImpl notifyPushAPNs];
}

- (void)notifyPushAPNs {
    DDLogVerbose(@"%@ notifyPushAPNs", LOG_TAG);

    TLTwinlifeStatus status = [self status];
    if (status == TLTwinlifeStatusStarted) {
        CFNotificationCenterPostNotification(self.darwinNotificationCenter, self.inBackground ? TL_NOTIFY_APP_BACKGROUND : TL_NOTIFY_APP_FOREGROUND, nil, nil, YES);
    }
}

- (void)twinlifeResume {
    DDLogVerbose(@"%@ twinlifeResume startTime: %lld", LOG_TAG, self.startTime);

    // Check immediately the status to avoid dispatching for nothing.
    TLTwinlifeStatus status = [self status];
    if (status == TLTwinlifeStatusUninitialized || status == TLTwinlifeStatusStarted
        || status == TLTwinlifeStatusStarting || status == TLTwinlifeStatusError || status == TLTwinlifeStatusStopped) {
        return;
    }

    TL_START_MEASURE(self.startTime)
    dispatch_block_t block = ^{

        // Get again the status because it could have changed while we wait on the dispatch queue.
        TLTwinlifeStatus status = [self status];
        if (status == TLTwinlifeStatusUninitialized || status == TLTwinlifeStatusStarted
            || status == TLTwinlifeStatusStarting || status == TLTwinlifeStatusError || status == TLTwinlifeStatusStopped) {
            return;
        }

        NSAssert(status == TLTwinlifeStatusConfigured || status == TLTwinlifeStatusSuspended || status == TLTwinlifeStatusSuspending, @"Invalid status for twinlifeResume");

        // Update the status to make sure we don't try to stop while we start!
        atomic_store(&self->_twinlifeStatus, TLTwinlifeStatusStarting);
        if (self.twinlifeConfiguration.enableSetup) {
            CFNotificationCenterAddObserver(self.darwinNotificationCenter, (__bridge const void *)(self), darwinNotificationObserver, TL_NOTIFY_APNS, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        } else {
            // For the NotificationServiceExtension, reload the secure keys
            self.twinlifeSecuredConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:self.serializerFactory alternateApplication:NO];
            if (!self.twinlifeSecuredConfiguration) {
                atomic_store(&self->_twinlifeStatus, TLTwinlifeStatusError);
                return;
            }
        }

        int64_t startDatabase = 0;
        TL_START_MEASURE(startDatabase)
        // Make sure the database is opened.
        if ([self openDatabase] != TLBaseServiceErrorCodeSuccess) {
            atomic_store(&self->_twinlifeStatus, TLTwinlifeStatusError);
            self.configured = NO;

        } else {
            self.connectionFailed = NO;
            for (TLBaseService *service in self.twinlifeServices) {
                if ([service isServiceOn]) {
                    [service onTwinlifeResume];
                }
            }
            atomic_store(&self->_twinlifeStatus, TLTwinlifeStatusStarted);
            TL_END_MEASURE(startDatabase, @"openDatabase")

            if (self.twinlifeSuspendObserver) {
                [self.twinlifeSuspendObserver onTwinlifeResume];
            }
            TL_END_MEASURE(self.startTime, @"twinlifeResume")

            // Don't try to connect if the account service is disabled.
            if (![self.accountService isReconnectable]) {
                return;
            }

            // Create a connection monitor instance dedicated to the new thread and stop a possible running connection monitor.
            TLConnectionMonitor *connectionMonitor;
            @synchronized (self) {
                connectionMonitor = [[TLConnectionMonitor alloc] init];
                if (self.connectionMonitor) {
                    self.connectionMonitor.running = NO;
                }
                self.connectionMonitor = connectionMonitor;
            }

            NSThread* thread = [[NSThread alloc] initWithTarget:self selector:@selector(run:) object:connectionMonitor];
            [thread setName:@"com.twinlife.ConnectionMonitor"];
            [thread start];
        }
    };

    // Run the resume code from the Twinlife queue to avoid problems and make sure:
    // 1/ everything in the Twinlife queue was executed,
    // 2/ after we return the database and services are in a well known state.
    if (dispatch_get_specific(self.twinlifeQueueTag)) {
        block();
    } else {
        dispatch_sync(self.twinlifeQueue, block);
    }
}

- (void)onSignIn {
    DDLogInfo(@"%@ onSignIn", LOG_TAG);
    
    [self openDatabase];
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onSignIn];
        }
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);

    // If a connection monitor is running, stop it.
    @synchronized (self) {
        if (self.connectionMonitor) {
            self.connectionMonitor.running = NO;
            self.connectionMonitor = nil;
        }
        
        self.online = NO;
        atomic_store(&_twinlifeStatus, TLTwinlifeStatusStopped);
    }

    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onSignOut];
        }
    }
    
    [self disconnect];
    
    [self removeDatabase];

    [self.twinlifeSecuredConfiguration erase];

    self.twinlifeSecuredConfiguration = nil;
}

- (void)onGetErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetErrorWithIQ", LOG_TAG);

    if (![iq isKindOfClass:[TLBinaryErrorPacketIQ class]]) {
        return;
    }

    TLBinaryErrorPacketIQ *errorPacketIQ = (TLBinaryErrorPacketIQ *)iq;
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onErrorWithErrorPacket:errorPacketIQ];
        }
    }
}

#if defined(DEBUG) && DEBUG == 1

- (void)developmentExportInternalFiles {
    // Use DDLogError for everything to have traces.
    DDLogError(@"%@ developmentExportInternalFiles", LOG_TAG);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
    
    // Export in a dedicated directory that we clear first.
    appDir = [appDir URLByAppendingPathComponent:EXPORT_DIR];
    if ([fileManager fileExistsAtPath:appDir.path]) {
        [fileManager removeItemAtPath:appDir.path error:nil];
    }
    [fileManager createDirectoryAtPath:appDir.path withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
    
    // Export twinlife-4.cipher in the private area.
    {
        NSURL *path = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
        NSString *cipherV4DatabasePath = path.path;
        if ([fileManager fileExistsAtPath:cipherV4DatabasePath]) {
            NSURL *target = [appDir URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
            DDLogError(@"%@ Export %@ to %@", LOG_TAG, cipherV4DatabasePath, target.path);
            
            [fileManager copyItemAtPath:cipherV4DatabasePath toPath:target.path error:nil];
        }
    }
    
    // Export twinlife-5.cipher in the private area.
    {
        NSURL *path = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
        NSString *cipherV5DatabasePath = path.path;
        if ([fileManager fileExistsAtPath:cipherV5DatabasePath]) {
            NSURL *target = [appDir URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
            DDLogError(@"%@ Export %@ to %@", LOG_TAG, cipherV5DatabasePath, target.path);
            
            [fileManager copyItemAtPath:cipherV5DatabasePath toPath:target.path error:nil];
        }
    }
    
    // NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:NO];
    
    NSData *content = [TLKeyChain getKeyChainDataWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG alternateApplication:NO];
    if (content) {
        NSURL *target = [appDir URLByAppendingPathComponent:EXPORT_TWINLIFE_CONFIGURATION];
        DDLogError(@"%@ Save %@", LOG_TAG, target.path);
        
        [content writeToFile:target.path atomically:YES];
    }
    content = [TLKeyChain getKeyChainDataWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG alternateApplication:NO];
    if (content) {
        NSURL *target = [appDir URLByAppendingPathComponent:EXPORT_ACCOUNT_CONFIGURATION];
        DDLogError(@"%@ Save %@", LOG_TAG, target.path);
        
        [content writeToFile:target.path atomically:YES];
    }
    {
        NSURL *target = [appDir URLByAppendingPathComponent:@"files"];
        if ([fileManager fileExistsAtPath:target.path]) {
            [fileManager removeItemAtPath:target.path error:nil];
        }
        // [fileManager createDirectoryAtPath:target.path withIntermediateDirectories:YES attributes:nil error:nil];

        NSError *error;
        NSURL *src = [groupURL URLByAppendingPathComponent:@"Conversations"];
        if ([fileManager fileExistsAtPath:src.path]) {
            [fileManager copyItemAtPath:src.path toPath:target.path error:&error];
            DDLogError(@"%@ Copied %@ to %@: %@", LOG_TAG, src.path, target.path, error);
        }

        target = [appDir URLByAppendingPathComponent:@"Migration"];
        if ([fileManager fileExistsAtPath:target.path]) {
            [fileManager removeItemAtPath:target.path error:nil];
        }
        src = [groupURL URLByAppendingPathComponent:@"Migration"];
        if ([fileManager fileExistsAtPath:src.path]) {
            [fileManager copyItemAtPath:src.path toPath:target.path error:&error];
            DDLogError(@"%@ Copied %@ to %@: %@", LOG_TAG, src.path, target.path, error);
        }
    }
}

- (void)developmentImportExternalFiles {
    // Use DDLogError for everything to have traces.
    DDLogError(@"%@ developmentImportExternalFiles", LOG_TAG);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];

    // Check if the Import dedicated directory exists.
    appDir = [appDir URLByAppendingPathComponent:IMPORT_DIR];
    if (![fileManager fileExistsAtPath:appDir.path]) {
        return;
    }

    // Start by exporting files to the export directory.
    [self developmentExportInternalFiles];

    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];

    // Import twinlife-5.cipher from the private area if it exists.
    NSURL *path = [appDir URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
    if ([fileManager fileExistsAtPath:path.path]) {
        NSURL *dbPath = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
        NSString *cipherV5DatabasePath = dbPath.path;
        DDLogError(@"%@ Import V5 database %@ to %@", LOG_TAG, path.path, cipherV5DatabasePath);
        [fileManager removeItemAtPath:cipherV5DatabasePath error:nil];
        [fileManager copyItemAtPath:path.path toPath:cipherV5DatabasePath error:nil];
    } else {
        // Import twinlife-4.cipher from the private area.
        path = [appDir URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
        if ([fileManager fileExistsAtPath:path.path]) {
            NSURL *dbPath = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
            NSString *cipherV4DatabasePath = dbPath.path;
            DDLogError(@"%@ Import V4 database %@ to %@", LOG_TAG, path.path, cipherV4DatabasePath);
            
            [fileManager removeItemAtPath:cipherV4DatabasePath error:nil];
            [fileManager copyItemAtPath:path.path toPath:cipherV4DatabasePath error:nil];
        } else {
            DDLogError(@"%@ No database found for the import.", LOG_TAG);
            return;
        }
    }

    path = [appDir URLByAppendingPathComponent:EXPORT_TWINLIFE_CONFIGURATION];
    if ([fileManager fileExistsAtPath:path.path]) {
        NSData *content = [fileManager contentsAtPath:path.path];

        if (![TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
            DDLogError(@"%@ loadWithSerializerFactory:twinlifeConfiguration: updateKeyChainWithKey error 2", LOG_TAG);
        }
    }

    path = [appDir URLByAppendingPathComponent:EXPORT_ACCOUNT_CONFIGURATION];
    if ([fileManager fileExistsAtPath:path.path]) {
        NSData *content = [fileManager contentsAtPath:path.path];

        if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
            DDLogError(@"%@ loadWithSerializerFactory:twinlifeConfiguration: updateKeyChainWithKey error 2", LOG_TAG);
        }
    }

    // Erase the import directory to make sure we don't import again.
    DDLogError(@"%@ Removing the import private directory", LOG_TAG);
    [fileManager removeItemAtPath:appDir.path error:nil];
}
#endif

#pragma mark - TLServerConnectionDelegate

- (void)onConnect {
    DDLogInfo(@"%@ onConnect", LOG_TAG);

    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onConnect];
        }
    }
}

- (void)onDisconnectWithError:(TLConnectionError)error {
    DDLogVerbose(@"%@ onDisconnectWithError: %ld", LOG_TAG, error);
    
    [self unlockServerConnection];
    
    for (TLBaseService *service in self.twinlifeServices) {
        if ([service isServiceOn]) {
            [service onDisconnect];
        }
    }
    
    // If we are suspending, close the database to enter in the final TLTwinlifeStatusSuspended state.
    if ([self status] == TLTwinlifeStatusSuspending) {
        [self.serverConnection triggerWorker];
        
        // First dispatch to execute after every code that was queued by the service onDisconnect.
        dispatch_async([self twinlifeQueue], ^{
            // The onDisconnect observers have queued several dispatch blocks and we must execute
            // them before closing the database (see TwinlifeContextImpl.onDisconnect).
            dispatch_async([self twinlifeQueue], ^{
                [self twinlifeSuspended];
            });
        });
        return;
    }
    [self.serverConnection triggerWorker];
}

- (void)didReceiveBinaryWithData:(nonnull NSData *)data {
    DDLogVerbose(@"%@ didReceiveBinaryWithData: %@", LOG_TAG, data);

    NSUUID *schemaId;
    int schemaVersion;
    @try {
        TLBinaryDecoder *binaryDecoder = [[TLBinaryCompactDecoder alloc] initWithData:data];
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
        TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:schemaId schemaVersion:schemaVersion];
        TLSerializer *serializer = [self.serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
        TLBinaryPacketListener listener = self.binaryPacketListeners[key];

        if (!listener || !serializer) {
            DDLogError(@"%@ didReceiveBinaryData: schema unsupported: %@.%d", LOG_TAG, schemaId, schemaVersion);
        } else {
            NSObject *object = [serializer deserializeWithSerializerFactory:self.serializerFactory decoder:binaryDecoder];
            if (![object isKindOfClass:[TLBinaryPacketIQ class]]) {
                DDLogError(@"%@ didReceiveBinaryData: invalid packet", LOG_TAG);
            } else {
                // Execute the operation handler from the server queue (so that we don't block the caller, which is the
                // connection monitor thread, and we can give the de-serialized IQ to another thread).
                dispatch_async(self.serverQueue, ^{
                    @try {
                        TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)object;
                        listener(iq);
                    } @catch(NSException *lException) {
                        DDLogError(@"%@ didReceiveBinaryData: exception: %@ schemaId: %@", LOG_TAG, lException, schemaId);
                    }
                });
            }
        }
    }
    @catch(NSException *lException) {
        DDLogError(@"%@ didReceiveBinaryData: exception: %@ schemaId: %@", LOG_TAG, lException, schemaId);
    }
}

#pragma mark - Private methods

- (BOOL)needInstall {
    DDLogVerbose(@"%@ needInstall", LOG_TAG);

    //                      userDefaults   DB       Secure config    Result action
    // Installation          <missing>   <missing>  <missing>        YES    fresh install
    // Installation          <missing>   <missing>  <known>          YES    erase secure config
#ifdef TWINME
    // Migrated to Twinme+   <missing>   <*>        <known>          YES    twinme migrated then uninstalled and re-installed
#endif
    // Migrated to Twinme+   <known>     <missing>  <known>          NO     stay in migrated state
    // Upgrade               <missing>   <known>    <known>          NO     none
    // Normal                <known>     <known>    <known>          NO     none
    NSString *data = [TLKeyChain getContentWithTag:@"installed" type:TLKeyChainTagTypePrivate];
    BOOL hasDb = [TLTwinlife hasDatabase];
#ifdef TWINME
    // Twinme was migrated to twinme+, the account is now disabled.
    // - if the 'installed' flag is there, do nothing so that we display the "Account has been migrated" message.
    // - otherwise, twinme was un-installed and for this new installation, we want to make an install.
    BOOL wasDisabled = [self.accountService isAccountDisabled];
    if (!data && wasDisabled) {
        return YES;
    }
#endif
    if (hasDb) {
        // Upgrading to new version: create the 'installed' user default in the private app area.
        if (!data) {
            [TLKeyChain saveContentWithTag:@"installed" type:TLKeyChainTagTypePrivate content:@"1"];
        }
        return NO;
    }

    return data ? NO : YES;
}

+ (BOOL)hasDatabase {
    DDLogVerbose(@"%@ hasDatabase", LOG_TAG);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
    NSURL *path = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
    if (!path) {
        DDLogError(@"%@ hasDatabase: invalid AppGroup", LOG_TAG);
        return NO;
    }
    if ([fileManager fileExistsAtPath:path.path]) {
        return YES;
    }

    path = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
    if (!path) {
        DDLogError(@"%@ hasDatabase: invalid AppGroup", LOG_TAG);
        return NO;
    }
    if ([fileManager fileExistsAtPath:path.path]) {
        return YES;
    }
    
    path = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
    if ([fileManager fileExistsAtPath:path.path]) {
        return YES;
    }

    path = [groupURL URLByAppendingPathComponent:CIPHER_V3_DATABASE_NAME];
    if ([fileManager fileExistsAtPath:path.path]) {
        return YES;
    }
    return NO;
}

- (TLBaseServiceErrorCode)openDatabase {
    DDLogVerbose(@"%@ openDatabase", LOG_TAG);
    
    @synchronized(self) {
        if (self.databaseQueue) {
            return TLBaseServiceErrorCodeSuccess;
        }
        
        // Migrate the database file to the App Shared container.
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
        if (!groupURL) {
            DDLogError(@"%@ openDatabase: invalid AppGroup", LOG_TAG);
            [self assertionWithAssertPoint:[TLTwinlifeAssertPoint BAD_CONFIGURATION], [TLAssertValue initWithLine:__LINE__], nil];
            return TLBaseServiceErrorCodeWrongLibraryConfiguration;
        }
        NSURL *path = [groupURL URLByAppendingPathComponent:CIPHER_V5_DATABASE_NAME];
        NSString *databasePath = path.path;
        NSString *databaseKey = self.twinlifeSecuredConfiguration.databaseKey;
        NSString *oldDatabaseKey = self.twinlifeSecuredConfiguration.oldDatabaseKey;
        int cipherVersion = 4;

        // Look for a V4 or V3 database if V5 does not exist.
        if (self.databaseVersion != DATABASE_VERSION && ![fileManager fileExistsAtPath:databasePath]) {
            NSURL *cipherV4DatabasePath = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
            NSURL *cipherV3DatabasePath = [groupURL URLByAppendingPathComponent:CIPHER_V3_DATABASE_NAME];
            BOOL hasV3 = [fileManager fileExistsAtPath:cipherV3DatabasePath.path];
            BOOL hasV4 = [fileManager fileExistsAtPath:cipherV4DatabasePath.path];
            NSError *cpError;
            
            // When setup is disabled (iOS extension), we are not allowed to migrate or create the database.
            if (!hasV4 && !hasV3 && !self.twinlifeConfiguration.enableSetup) {
                
                return TLBaseServiceErrorCodeNoPermission;
            }

            // If the database V4 cipher file does not exist, look for V3 cipher file.
            // We could also have the V4 but a short key which means the V3 file has not completed its migration.
            // Note: the old case where the database was not encrypted is no longer supported (migration done in 2017).
            if (hasV3 && (!hasV4 || databaseKey.length != 96)) {
                // Mark we are upgrading before the V3 -> V4 migration.
                self.databaseUpgraded = YES;
                    
                // Get a new database encryption key for the V4 implementation.
                BOOL success;
                NSString *newKey = [TLTwinlifeSecuredConfiguration generateDatabaseKey];
                if (!newKey) {
                    success = NO;
                } else {
                    // Make sure the V4 cipher database file does not exist
                    // (it could in some rare cases if we are interrupted in the middle of database migration).
                    // Migrate the V3 to the intermediate V4!
                    [fileManager removeItemAtPath:cipherV4DatabasePath.path error:nil];
                    success = [self tryMigrateCipher3WithPath:cipherV3DatabasePath.path newPath:cipherV4DatabasePath.path newKey:newKey];
                        
                    // Database was successfully migrated save the encryption key NOW!
                    // (see second call to changeDatabaseKeyWithKey later).
                    if (success) {
                        success = [self.twinlifeSecuredConfiguration changeDatabaseKeyWithKey:newKey];
                    }
                }
                    
                if (success) {
                    DDLogWarn(@"%@ openDatabase: migration to SQLCipher 4 done", LOG_TAG);
                    [fileManager removeItemAtPath:cipherV3DatabasePath.path error:nil];
                    cipherVersion = 4;
                    databaseKey = newKey;
                    hasV4 = YES;
                } else {
                    DDLogError(@"%@ openDatabase: migration to SQLCipher 4 failed, using SQLCipher 3", LOG_TAG);
                        
                    // If the V3 to V4 migration failed, make sure the new database V4 file does not exist.
                    // (it could be partially created and something failed).
                    if ([fileManager fileExistsAtPath:cipherV4DatabasePath.path]) {
                        DDLogWarn(@"%@ removing failed database migration file", LOG_TAG);
                        [fileManager removeItemAtPath:cipherV4DatabasePath.path error:nil];
                    }
                        
                    // Use SQLCipher v4 in compatibility mode.
                    cipherVersion = 3;
                    databasePath = cipherV3DatabasePath.path;
                }
            }
            
            if (hasV4) {
                //DDLogError(@"%@ Copy old V4 to V5 for testing migration", LOG_TAG);
                [fileManager moveItemAtPath:cipherV4DatabasePath.path toPath:databasePath error:&cpError];
                if (cpError) {
                    DDLogError(@"%@ openDatabase: failed to copy database: %@", LOG_TAG, cpError);
                    return TLBaseServiceErrorCodeNoStorageSpace;
                }
            }
        }

        // Doing an installation, make sure there is no database.
        if (self.isInstalled) {
            [fileManager removeItemAtPath:databasePath error:nil];
        }
#if defined(DEBUG) && DEBUG == 1
        DDLogError(@"%@ Using database key %@ and old key %@", LOG_TAG, databaseKey, oldDatabaseKey);
#endif

        BOOL databaseExists = [fileManager fileExistsAtPath:databasePath];
        self.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:databasePath];
        self.databasePath = databasePath;
        // Check databaseKey
        __block NSError *error = nil;
        __block int databaseVersion = 0;
        [self.databaseQueue inDatabase:^(FMDatabase *database) {
            if (cipherVersion == 3) {
                [database setKey:databaseKey];
                [database executeUpdate:@"PRAGMA cipher_compatibility = 3"];
            } else {
                // Keep 32 bytes header in clear text for iOS for Apple's stupidities.
                [database executeUpdate:@"PRAGMA cipher_plaintext_header_size = 32"];
                [database setKey:[NSString stringWithFormat:@"x'%@'", databaseKey]];
            }
            
            // Always check the database key in case the file was changed behind us.
            FMResultSet *resultSet = [database executeQuery:@"SELECT COUNT(*) FROM sqlite_master" values:nil error:&error];
            [resultSet close];
            if (error) {
                return;
            }

            databaseVersion = [database intForQuery:@"PRAGMA user_version"];
            if (databaseVersion < 20) {
                int result = [database intForQuery:@"SELECT COUNT(*) FROM sqlite_master WHERE [type]='table' AND name='databaseVersion'"];
                if (result > 0) {
                    databaseVersion = [database intForQuery:@"SELECT version FROM databaseVersion WHERE key='twinlifeDatabase'"];
                }
                if (!databaseVersion) {
                    // Database was created with version >14 and <21, so it has neither a user_version PRAGMA nor a databaseVersion table.
                    // Set the version manually, to make sure upgrades run and the user_version PRAGMA is set.
                    int result = [database intForQuery:@"SELECT COUNT(*) FROM sqlite_master WHERE [type]='table' AND name='repository'"];
                    if (result == 0) {
                        databaseVersion = 19;
                    } else {
                        databaseVersion = 20;
                    }
                }
            }
        }];

        if (error) {
            DDLogError(@"%@ check database failed with error %@", LOG_TAG, error);
            self.databaseError = error; // Record the error (used for debugging).
            [self.databaseQueue close];
            switch (error.code) {
                case SQLITE_NOTADB:
                    return TLBaseServiceErrorCodeDatabaseKeyError;
                case SQLITE_FULL:
                    return TLBaseServiceErrorCodeNoStorageSpace;
                default:
                    return TLBaseServiceErrorCodeDatabaseError;
            }
        }
        
        if (self.databaseVersion <= 0) {
            self.databaseVersion = databaseVersion;

            // Database was successfully migrated save the encryption key.
            if (![databaseKey isEqual:self.twinlifeSecuredConfiguration.databaseKey]) {
                [self.twinlifeSecuredConfiguration changeDatabaseKeyWithKey:databaseKey];
            }
        }

        TLBaseServiceErrorCode result = TLBaseServiceErrorCodeSuccess;
        if (!databaseExists) {
            [self.databaseService onCreateWithDatabaseQueue:self.databaseQueue version:DATABASE_VERSION];

            // Save the `installed` tag when our database is created (see needInstall).
            [TLKeyChain saveContentWithTag:@"installed" type:TLKeyChainTagTypePrivate content:@"1"];

        } else if (self.databaseVersion != DATABASE_VERSION) {
            self.databaseUpgraded = YES;
            result = [self.databaseService onUpgradeWithDatabaseQueue:self.databaseQueue oldVersion:self.databaseVersion newVersion:DATABASE_VERSION];

            if (result == TLBaseServiceErrorCodeSuccess) {
                [self.databaseQueue inDatabase:^(FMDatabase *database) {
                    [database executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %@", [NSNumber numberWithInt:DATABASE_VERSION]]];
                    // Remove old version table at the end when the SQLite version is updated.
                    if (self.databaseVersion < 20) {
                        [database executeUpdate:@"DROP TABLE IF EXISTS databaseVersion"];
                    }
                }];
                self.databaseVersion = DATABASE_VERSION;
            }

        } else if (databaseExists) {
            [self.databaseService onOpenWithDatabaseQueue:self.databaseQueue];
        }

        return result;
    }
}

- (BOOL)tryMigrateCipher3WithPath:(nonnull NSString *)path newPath:(nonnull NSString *)newPath newKey:(nonnull NSString *)newKey {
    DDLogInfo(@"%@ tryMigrateCipher3WithPath: %@ newPath: %@ newKey: %@", LOG_TAG, path, newPath, newKey);

#if SQLITE_VERSION_NUMBER < 3039004
    DDLogError(@"%@ *** WARNING ***: using the SQLCipher version based on SQLITE %s", LOG_TAG, SQLITE_VERSION);

    return NO;
#else
    // Using the new SQLCipher v4.5.2 version
    // If only one SQLite call fails, we must terminate and report a failure.
    // We will continue using the SQLCipher compatibility mode.

    sqlite3 *database;
    if (sqlite3_open([path UTF8String], &database) != SQLITE_OK) {
        return NO;
    }

    NSData *keyData = [NSData dataWithBytes:[self.twinlifeSecuredConfiguration.databaseKey UTF8String] length:(NSUInteger)strlen([self.twinlifeSecuredConfiguration.databaseKey UTF8String])];
    int rc = sqlite3_key(database, [keyData bytes], (int)[keyData length]);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    rc = sqlite3_exec(database, "PRAGMA cipher_compatibility = 3", NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(database);
        return NO;
    }

    sqlite3_stmt *stmt;
    rc = sqlite3_prepare_v2(database, "SELECT version FROM databaseVersion WHERE key='twinlifeDatabase'", -1, &stmt, 0);
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
#endif
}

- (void)closeDatabase {
    DDLogVerbose(@"%@ closeDatabase", LOG_TAG);
    
    @synchronized(self) {
        if (!self.databaseQueue) {
            return;
        }
        
        [self.databaseQueue close];
        self.databaseQueue = nil;
        [self.databaseService onCloseDatabase];
        
        TLTwinlifeStatus status = [self status];
        if (status == TLTwinlifeStatusSuspending || status == TLTwinlifeStatusStarted || status == TLTwinlifeStatusConfigured) {
            atomic_store(&_twinlifeStatus, TLTwinlifeStatusSuspended);
        }
    }
}

- (void)removeDatabase {
    DDLogVerbose(@"%@ removeDatabase", LOG_TAG);
    
    @synchronized(self) {
        if (!self.databaseQueue) {
            return;
        }
        
        [self.databaseQueue close];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
        NSURL *cipherDatabasePath = [groupURL URLByAppendingPathComponent:CIPHER_V4_DATABASE_NAME];
        [fileManager removeItemAtPath:cipherDatabasePath.path error:nil];
        cipherDatabasePath = [groupURL URLByAppendingPathComponent:CIPHER_V3_DATABASE_NAME];
        [fileManager removeItemAtPath:cipherDatabasePath.path error:nil];
        self.databaseQueue = nil;
    }
}

- (void)prepareForRestart {
    DDLogVerbose(@"%@ prepareForRestart", LOG_TAG);

    // Doing a twinlifeSuspend + twinlifeResume is not enough to restart after a device migration
    // because we have several upper layer services that could still use and reference old device
    // objects.
    self.forceApplicationRestart = YES;
    atomic_store(&_twinlifeStatus, TLTwinlifeStatusUninitialized);
}

- (nonnull NSString *)toBareJIDWithUsername:(nonnull NSString *)username {
    DDLogVerbose(@"%@ toBareJIDWithUsername: %@", LOG_TAG, username);

    NSString *lowercaseUsername = [username lowercaseString];
    NSString *escapedName = [lowercaseUsername stringByReplacingOccurrencesOfString:@"/" withString:@"\\2f"];
    return [NSString stringWithFormat:@"%@@%@", escapedName, [TLTwinlife TWINLIFE_DOMAIN]];
}

- (void)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ errorWithErrorCode: %d errorParameter= %@", LOG_TAG, errorCode, errorParameter);

    if (self.managementService) {
        [self.managementService errorWithErrorCode:errorCode errorParameter:errorParameter];
    }
}

- (BOOL)lockServerConnection {
    DDLogVerbose(@"%@ lockServerConnection %@ fd: %d", LOG_TAG, self.connectLockFile, self.connectLockFd);

    // Open the lock file and try to get the lock.  We keep the file opened until we have the lock.
    if (self.connectLockFd < 0) {
        int lockFd = open([self.connectLockFile UTF8String], O_CREAT | O_RDWR, 0600);
        if (lockFd < 0) {
            DDLogError(@"%@ cannot open file: %d", LOG_TAG, errno);
            return NO;
        }

        int result = flock(lockFd, LOCK_EX | LOCK_NB);
        if (result < 0) {
            DDLogVerbose(@"%@ server connection is locked %d", LOG_TAG, errno);
            close(lockFd);
            return NO;
        }

        self.connectLockFd = lockFd;
    }
    return YES;
}

- (void)unlockServerConnection {
    DDLogVerbose(@"%@ unlockServerConnection lockFd: %d", LOG_TAG, self.connectLockFd);

    if (self.connectLockFd >= 0) {
        flock(self.connectLockFd, LOCK_UN);
        close(self.connectLockFd);
        self.connectLockFd = -1;
    }
}

- (void)run:(id)object {
    DDLogVerbose(@"%@ run: %@", LOG_TAG, object);
    
    TLConnectionMonitor *monitor = (TLConnectionMonitor *)object;
    if (!self.isConfigured) {
        monitor.running = NO;
    }

    NSTimeInterval disconnectedTimeout = 0.1;
    while (monitor.running) {
        do {
            DDLogInfo(@"%@ %@", LOG_TAG, @"wait for connected network...");

            // If we have some active P2P session, reduce the disconnect timeout to 1s when it is below 16.
            // In that case, we will use 1, 2s, 4s, 8s network detection timeout.
            if ([self.jobService isVoIPActive]) {
                disconnectedTimeout = 0.1;
            } else if (![self.jobService isIdle]) {
                // If we are not idle (app in foreground), be more pro-active in testing the network connectivity.
                // The delay will start at 0 and we increase it by 250ms min until we reach 10s and then we start
                // again from 1s.
                // 0, 250, 625, 1187, 2030, 3305, 5207, 8060
                disconnectedTimeout = 0.25 + (disconnectedTimeout / 2.0);
                if (disconnectedTimeout > 10.0) {
                    disconnectedTimeout = 1.0;
                }
            }
            if (![self.connectivityService waitForConnectedNetworkWithTimeout:disconnectedTimeout]) {
                DDLogInfo(@"%@ %@", LOG_TAG, @"network not connected");

                disconnectedTimeout *= 2;
                if (disconnectedTimeout > MAX_DISCONNECTED_TIMEOUT) {
                    disconnectedTimeout = MAX_DISCONNECTED_TIMEOUT;
                }
            }
        } while (![self.connectivityService isConnectedNetwork] && monitor.running);

        // Do not try to re-connect if we are disconnecting.
        BOOL hasLock = NO;
        if (![self.serverConnection isDisconnecting]) {

            while (monitor.running && [self.connectivityService isConnectedNetwork]) {
                if (![self isConnected] && monitor.running) {
                    hasLock = [self lockServerConnection];
                    if (hasLock) {
                        DDLogInfo(@"%@ %@", LOG_TAG, @"connect...");
                        
                        if (![self.serverConnection connect]) {
                            // Connection failed immediately, may be the Internet connectivity was lost,
                            // exit this loop to check again BUT give 500ms to the libwebsocket to pause
                            // because if we retry the call to connect() too quickly, we will get the
                            // same error and consume CPU for nothing.
                            [self.serverConnection serviceWithTimeout:500];
                            break;
                        }
                    }
                }
                [self.serverConnection serviceWithTimeout:5000];
            }

            [self unlockServerConnection];
        }
    }
    while ([self.serverConnection isOpened] || [self.serverConnection isDisconnecting]) {
        [self.serverConnection serviceWithTimeout:10];
    }
    DDLogVerbose(@"%@ stopping thread: %@", LOG_TAG, object);
}

- (NSString *)getModel {
    DDLogVerbose(@"%@ getModel", LOG_TAG);
    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *buffer = malloc(size);
    sysctlbyname("hw.machine", buffer, &size, NULL, 0);
    NSString *model = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    free(buffer);
    return [model stringByReplacingOccurrencesOfString:@"," withString:@"_"];
}

@end
