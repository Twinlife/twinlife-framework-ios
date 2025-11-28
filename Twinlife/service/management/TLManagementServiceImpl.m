/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 */

#import <CocoaLumberjack.h>
#import <CommonCrypto/CommonDigest.h>
#import <malloc/malloc.h>

#import "TLJobService.h"
#import "TLManagementServiceImpl.h"
#import "TLAccountServiceImpl.h"
#import "TLJobServiceImpl.h"
#import "TLBaseServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLDatabaseService.h"
#import "TLPeerConnectionServiceImpl.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLValidateConfigurationIQ.h"
#import "TLUpdateConfigurationIQ.h"
#import "TLOnValidateConfigurationIQ.h"
#import "TLSetPushTokenIQ.h"
#import "TLLogEventIQ.h"
#import "TLFeedbackIQ.h"
#import "TLAssertionIQ.h"
#import "TLDeviceInfo.h"
#import "TLAssertion.h"
#import "TLProxyDescriptor.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define MANAGEMENT_SERVICE_VERSION @"2.2.1"

#define MANAGEMENT_SERVICE_PREFERENCES_HAS_CONFIGURATION @"ManagementServiceHasConfiguration"
#define MANAGEMENT_SERVICE_PREFERENCES_MAX_SENT_FRAME_SIZE @"MaxSentFrameSize"
#define MANAGEMENT_SERVICE_PREFERENCES_MAX_SENT_FRAME_RATE @"MaxSentFrameRate"
#define MANAGEMENT_SERVICE_PREFERENCES_MAX_RECEIVED_FRAME_SIZE @"MaxReceivedFrameSize"
#define MANAGEMENT_SERVICE_PREFERENCES_MAX_RECEIVED_FRAME_RATE @"MaxReceivedFrameRate"
#define MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_VARIANT @"PushNotificationVariant"
#define MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_TOKEN @"PushNotificationToken"
#define MANAGEMENT_SERVICE_PREFERENCES_PUSH_REMOTE_NOTIFICATION_TOKEN @"PushRemoteNotificationToken"

#define VALIDATE_CONFIGURATION_HARDWARE @"hardware"
#define VALIDATE_CONFIGURATION_SOFTWARE @"software"
#define VALIDATE_CONFIGURATION_POWER_MANAGEMENT @"power-management"
#define VALIDATE_CONFIGURATION_CONNECT_STATS    @"connect-stats"
#define VALIDATE_CONFIGURATION_TIMEZONE         @"timezone"

#define MAX_EVENTS     16
#define MAX_ASSERTIONS 16

#define MIN_UPDATE_TTL     120        // 2mn
#define DEFAULT_TTL      86400        // sec
#define CRASH_MIN_DELAY  86400        // Delay in seconds to wait before reporting two crashes (=1d).

#define VALIDATE_CONFIGURATION_SCHEMA_ID       @"437466BB-B2AC-4A53-9376-BFE263C98220"
#define SET_PUSH_TOKEN_SCHEMA_ID               @"3c1115d7-ed74-4445-b689-63e9c10eb50c"
#define UPDATE_CONFIGURATION_SCHEMA_ID         @"3b726b45-c3fc-4062-8ecd-0ddab2dd1537"
#define LOG_EVENT_SCHEMA_ID                    @"a2065d6f-a7aa-43cd-9c0e-030ece70d234"
#define FEEDBACK_SCHEMA_ID                     @"B3ED091A-4DB9-4C9B-9501-65F11811738B"
#define ASSERTION_SCHEMA_ID                    @"debcf418-2d3d-4477-97e1-8f7b4507ce8a"

#define ON_VALIDATE_CONFIGURATION_SCHEMA_ID    @"A0589646-2B24-4D22-BE5B-6215482C8748"
#define ON_SET_PUSH_TOKEN_SCHEMA_ID            @"e7596131-6e4d-47f1-b8a0-c747d3ae70f9"
#define ON_UPDATE_CONFIGURATION_SCHEMA_ID      @"2ab7ff5b-3043-4cbb-bb12-dda405fcd285"
#define ON_LOG_EVENT_SCHEMA_ID                 @"99286975-56dc-40d1-8df5-bce6b9e914f9"
#define ON_FEEDBACK_SCHEMA_ID                  @"DF59B7F3-D0D3-4A96-9B7A-1671B1627AEF"

//
// Interface: TLManagementJob
//
@interface TLManagementJob : NSObject <TLJob>

@property (weak, readonly) TLManagementService *service;

- (nonnull instancetype)initWithService:(nonnull TLManagementService *)service;

@end

//
// Interface: TLManagementJob
//
@interface TLManagementService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) TLManagementJob *managementJob;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLManagementPendingRequest *> *pendingRequests;
@property (readonly, nonnull) NSMutableArray<TLAssertionIQ *> *pendingAssertions;
@property (nullable) NSUUID *applicationId;
@property (nullable) TLVersion *applicationVersion;
@property BOOL saveEnvironment;
@property BOOL validatedConfiguration;
@property BOOL enableAudioVideo;
@property (nullable) NSUUID* environmentId;
@property (nullable) NSString* pushNotificationVariant;
@property (nullable) NSString* pushNotificationVoIPToken;
@property (nullable) NSString* pushNotificationRemoteToken;
@property BOOL setPushNotificationTokenDone;
@property BOOL mustCleanEnvironment;
@property BOOL checkPreviousCrash;
@property (nonnull) NSMutableArray *events;
@property (nullable) TLJobId *refreshJobId;
@property int64_t firstAssertionTime;
@property int assertionCount;

- (void)runRefreshJob;

@end

static TLBinaryPacketIQSerializer *IQ_VALIDATE_CONFIGURATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SET_PUSH_TOKEN_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_UPDATE_CONFIGURATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_LOG_EVENT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_FEEDBACK_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ASSERTION_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_ON_VALIDATE_CONFIGURATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SET_PUSH_TOKEN_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_UPDATE_CONFIGURATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_LOG_EVENT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_FEEDBACK_SERIALIZER = nil;

static NSString *crashFile;

void uncaughtExceptionHandler(NSException *exception) {
    DDLogError(@"Twinlife Oops: %@", exception);

    if (crashFile) {
        int crashFd = open([crashFile UTF8String], O_CREAT | O_RDWR | O_TRUNC, 0600);
        if (crashFd >= 0) {
            char buffer[256];
            const char *s = [exception.name UTF8String];
            if (s) {
                strncpy(buffer, s, sizeof(buffer));
                strncat(buffer, " ", 1);
            } else {
                strncat(buffer, "Unknown exception name", 40);
            }
            s = [exception.reason UTF8String];
            if (s) {
                strncat(buffer, s, 128);
            }
            strncat(buffer, "\n", 1);
            strncat(buffer, "Exception\n", 20);
            write(crashFd, buffer, strlen(buffer));

            for (NSString *sym in [exception callStackSymbols]) {
                const char *s = [sym UTF8String];
                
                write(crashFd, s, strlen(s));
                write(crashFd, "\n", 1);
            }
            close(crashFd);
            DDLogError(@"Crash information saved in %@", crashFile);
        }

        DDLogError(@"Stack Trace: %@", [exception callStackSymbols]);
        // Internal error reporting
    }
}

//
// Interface: TLManagementServiceAssertPoint ()
//

@implementation TLManagementServiceAssertPoint

TL_CREATE_ASSERT_POINT(ENVIRONMENT, 400)

@end

//
// Implementation: TLManagementJob
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementJob"

@implementation TLManagementJob

- (nonnull instancetype)initWithService:(nonnull TLManagementService *)service {

    self = [super init];
    if (self) {
        _service = service;
    }

    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    [self.service runRefreshJob];
}

@end

//
// Implementation: TLManagementServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementServiceConfiguration"

@implementation TLManagementServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdManagementService version:[TLManagementService VERSION] serviceOn:YES];
    
    return self;
}

@end

//
// Implementation: TLEvent
//

#undef LOG_TAG
#define LOG_TAG @"TLEvent"

@implementation TLEvent

- (instancetype)initWithEventId:(NSString *)eventId attributes:(NSDictionary *)attributes {
    DDLogVerbose(@"%@ initWithEventId: %@ attributes: %@", LOG_TAG, eventId, attributes);
    
    self = [super init];
    
    if (self) {
        _eventId = eventId;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _attributes = attributes;
    }
    return self;
}

- (instancetype)initWithEventId:(NSString *)eventId key:(NSString *)key value:(NSString *)value {
    DDLogVerbose(@"%@ initWithEventId: %@ key: %@ value: %@", LOG_TAG, eventId, key, value);
    
    self = [super init];
    
    if (self) {
        _eventId = eventId;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _key = key;
        _value = value;
    }
    return self;
}

@end

//
// Implementation: TLManagementPendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementPendingRequest"

@implementation TLManagementPendingRequest

@end

//
// Implementation: TLManagementEventsPendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementEventsPendingRequest"

@implementation TLManagementEventsPendingRequest

- (nonnull instancetype)initWithEvents:(nonnull NSArray<TLEvent *> *)events {
    DDLogVerbose(@"%@ initWithEvents: %@", LOG_TAG, events);
    
    self = [super init];
    
    if (self) {
        _events = events;
    }
    return self;
}

@end

//
// Implementation: TLManagementFeedbackPendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementFeedbackPendingRequest"

@implementation TLManagementFeedbackPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull TLFeedbackConsumer)complete {
    DDLogVerbose(@"%@ initWithConsumer: %@", LOG_TAG, complete);
    
    self = [super init];
    if (self) {
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLManagementService
//

#undef LOG_TAG
#define LOG_TAG @"TLManagementService"

@implementation TLManagementService

+ (void)initialize {
    
    IQ_VALIDATE_CONFIGURATION_SERIALIZER = [[TLValidateConfigurationIQSerializer alloc] initWithSchema:VALIDATE_CONFIGURATION_SCHEMA_ID schemaVersion:2];
    IQ_SET_PUSH_TOKEN_SERIALIZER = [[TLSetPushTokenIQSerializer alloc] initWithSchema:SET_PUSH_TOKEN_SCHEMA_ID schemaVersion:1];
    IQ_UPDATE_CONFIGURATION_SERIALIZER = [[TLUpdateConfigurationIQSerializer alloc] initWithSchema:UPDATE_CONFIGURATION_SCHEMA_ID schemaVersion:2];
    IQ_LOG_EVENT_SERIALIZER = [[TLLogEventIQSerializer alloc] initWithSchema:LOG_EVENT_SCHEMA_ID schemaVersion:1];
    IQ_FEEDBACK_SERIALIZER = [[TLFeedbackIQSerializer alloc] initWithSchema:FEEDBACK_SCHEMA_ID schemaVersion:1];
    IQ_ASSERTION_SERIALIZER = [[TLAssertionIQSerializer alloc] initWithSchema:ASSERTION_SCHEMA_ID schemaVersion:1];

    IQ_ON_VALIDATE_CONFIGURATION_SERIALIZER = [[TLOnValidateConfigurationIQSerializer alloc] initWithSchema:ON_VALIDATE_CONFIGURATION_SCHEMA_ID schemaVersion:2];
    IQ_ON_SET_PUSH_TOKEN_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_SET_PUSH_TOKEN_SCHEMA_ID schemaVersion:1];
    IQ_ON_UPDATE_CONFIGURATION_SERIALIZER = [[TLOnValidateConfigurationIQSerializer alloc] initWithSchema:ON_UPDATE_CONFIGURATION_SCHEMA_ID schemaVersion:2];
    IQ_ON_LOG_EVENT_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_LOG_EVENT_SCHEMA_ID schemaVersion:1];
    IQ_ON_FEEDBACK_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_FEEDBACK_SCHEMA_ID schemaVersion:1];
}

+ (NSString *)VERSION {
    
    return MANAGEMENT_SERVICE_VERSION;
}

- (instancetype)initWithTwinlife:(TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    if (self) {
        _validatedConfiguration = NO;
        _setPushNotificationTokenDone = YES;
        _mustCleanEnvironment = NO;
        _events = [[NSMutableArray alloc] init];
        _pendingAssertions = [[NSMutableArray alloc] init];
        _serializerFactory = twinlife.serializerFactory;
        _pendingRequests = [[NSMutableDictionary alloc] init];
        _managementJob = [[TLManagementJob alloc] initWithService:self];
        _firstAssertionTime = 0;
        _assertionCount = 0;

        // Register the binary IQ handlers for the responses.
        [twinlife addPacketListener:IQ_ON_VALIDATE_CONFIGURATION_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onValidateConfigurationWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_SET_PUSH_TOKEN_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onSetPushTokenWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_UPDATE_CONFIGURATION_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onUpdateConfigurationWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_LOG_EVENT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onLogEventWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_FEEDBACK_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onFeedbackWithIQ:iq];
        }];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
        NSString *prevCrashPath = [appDir URLByAppendingPathComponent:@"twinlife-crash.stamp"].path;
        int64_t lastCrashStamp = 0;

        // Check if a previous crash occurred and protect to report at most 1 crash per day.
        if ([fileManager fileExistsAtPath:prevCrashPath]) {
            NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:prevCrashPath error:nil];

            if (fileAttribs) {
                NSDate *result = [fileAttribs objectForKey:NSFileCreationDate];
                if (result) {
                    lastCrashStamp = [result timeIntervalSince1970];
                    int64_t now = [[NSDate date] timeIntervalSince1970];
                    if (lastCrashStamp + 1 < now) {
                        // This crash is old, we can forget about it.
                        [fileManager removeItemAtPath:prevCrashPath error:nil];
                        lastCrashStamp = 0;
                    }
                }
            }
        }

        // Install crash handler.
        if (lastCrashStamp == 0) {
            NSString *crashPath = [appDir URLByAppendingPathComponent:@"twinlife-crash.txt"].path;

            crashFile = crashPath;
            NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
            _checkPreviousCrash = YES;
        } else {
            _checkPreviousCrash = NO;
        }
    }
    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration applicationId:(nonnull NSUUID *)applicationId {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLManagementServiceConfiguration* managementServiceConfiguration = [[TLManagementServiceConfiguration alloc] init];
    TLManagementServiceConfiguration* serviceConfiguration = (TLManagementServiceConfiguration *) baseServiceConfiguration;
    managementServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    managementServiceConfiguration.saveEnvironment = serviceConfiguration.saveEnvironment;
    self.configured = YES;
    self.saveEnvironment = managementServiceConfiguration.saveEnvironment;
    self.serviceConfiguration = managementServiceConfiguration;
    self.enableAudioVideo = managementServiceConfiguration.saveEnvironment;
    self.serviceOn = managementServiceConfiguration.isServiceOn;
    self.applicationId = applicationId;
    self.applicationVersion = [[TLVersion alloc] initWithVersion:self.twinlife.twinlifeConfiguration.applicationVersion];
}

- (void)onCreate {
    DDLogVerbose(@"%@ onCreate", LOG_TAG);
    
    [super onCreate];
    
    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    self.validatedConfiguration = NO;
    
    // Get the environment from the account service.
    self.environmentId = [self.twinlife.accountService environmentId];
    if (!self.environmentId) {
        // We need the environment id for the encryption key and it must be the same between the main app and its extension.
        id value = [userDefaults objectForKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
        if (value) {
            self.environmentId = [[NSUUID alloc] initWithUUIDString:value];
            self.mustCleanEnvironment = YES;
        } else if (self.saveEnvironment) {
            NSUserDefaults *oldUserDefaults = [NSUserDefaults standardUserDefaults];
        
            // Get the environment from the old location.
            value = [oldUserDefaults objectForKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
            if (value) {
                self.environmentId = [[NSUUID alloc] initWithUUIDString:value];
                self.mustCleanEnvironment = YES;
            }
        }
    }

    self.configuration = [[TLBaseServiceImplConfiguration alloc] init];
    
    self.pushNotificationVariant = [userDefaults stringForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_VARIANT];
    self.pushNotificationVoIPToken = [userDefaults stringForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_TOKEN];
    self.pushNotificationRemoteToken = [userDefaults stringForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_REMOTE_NOTIFICATION_TOKEN];
    
    // For iOS 13, if the remote APNS token is empty, force a 'wait' token so that the server will not
    // try to use the PushKit to wakeup the device for new messages: we must not use PushKit until
    // we can use a valid APNS token.
    // For iOS < 13, the remote APNS token is nil and must not be used (see Notification Service app extension).
    if (@available(iOS 13.0, *)) {
        if (!self.pushNotificationRemoteToken) {
            self.pushNotificationRemoteToken = TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_APNS_WAIT;
        }
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    self.validatedConfiguration = NO;
    if (self.refreshJobId) {
        [self.refreshJobId cancel];
        self.refreshJobId = nil;
    }
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    [super onSignIn];
    
    [self validateConfigurationWithRequestId:[TLTwinlife newRequestId]];
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [super onSignOut];
    
    self.validatedConfiguration = NO;
    
    // Invalidate the environment and push tokens in case we try to connect again.
    self.environmentId = nil;
    self.pushNotificationRemoteToken = nil;
    self.pushNotificationVariant = nil;
    self.pushNotificationVoIPToken = nil;
    self.pushNotificationRemoteToken = nil;
    
    // For iOS 13, force a 'wait' token so that the server will not try to use the PushKit to wakeup
    // the device for new messages: we must not use PushKit until we can use a valid APNS token.
    // For iOS < 13, the remote APNS token is nil and must not be used (see Notification Service app extension).
    if (@available(iOS 13.0, *)) {
        self.pushNotificationRemoteToken = TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_APNS_WAIT;
    }
    
    [self sendEvents:YES];
    
    // Erase all keys to remove everything (both in the AppGroup and in the user defaults).
    [self eraseConfiguration:[TLTwinlife getAppSharedUserDefaults]];
    [self eraseConfiguration:[NSUserDefaults standardUserDefaults]];
}

- (void)eraseConfiguration:(NSUserDefaults *)configuration {
    DDLogVerbose(@"%@ eraseConfiguration: %@", LOG_TAG, configuration);
    
    // Remove the keys one by one (the setPersistentDomain and removePersistentDomainForName don't do the job).
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_VARIANT];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_TOKEN];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_REMOTE_NOTIFICATION_TOKEN];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_MAX_SENT_FRAME_SIZE];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_MAX_SENT_FRAME_RATE];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_MAX_RECEIVED_FRAME_SIZE];
    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_MAX_RECEIVED_FRAME_RATE];
}

- (void)eraseOldEnvironment:(NSUserDefaults *)configuration {
    DDLogVerbose(@"%@ eraseOldEnvironment: %@", LOG_TAG, configuration);

    [configuration removeObjectForKey:MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID];
}

#pragma mark - TLManagementService

- (void)setPushNotificationWithVariant:(NSString *)variant token:(NSString *)token {
    DDLogVerbose(@"%@ setPushNotificationWithVariant %@ token: %@", LOG_TAG, variant, token);
    
    if ([variant isEqualToString:TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_REMOTE_VARIANT]) {
        if ([token isEqualToString:self.pushNotificationRemoteToken]) {
            return;
        }
        self.pushNotificationRemoteToken = token;
    } else {
        // only one push mechanism at a given time
        if ([variant isEqualToString:self.pushNotificationVariant] && [token isEqualToString:self.pushNotificationVoIPToken]) {
            return;
        }
        
        self.pushNotificationVariant = variant;
        self.pushNotificationVoIPToken = token;
    }
    self.setPushNotificationTokenDone = NO;
    
    if (self.pushNotificationVoIPToken) {
        NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
        [userDefaults setObject:self.pushNotificationVariant forKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_VARIANT];
        [userDefaults setObject:self.pushNotificationVoIPToken forKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_NOTIFICATION_TOKEN];
        if (self.pushNotificationRemoteToken) {
            [userDefaults setObject:self.pushNotificationRemoteToken forKey:MANAGEMENT_SERVICE_PREFERENCES_PUSH_REMOTE_NOTIFICATION_TOKEN];
        }
        [userDefaults synchronize];
        
        [self setPushNotificationToken];
    }
}

- (void)validateConfigurationWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ validateConfigurationWithRequestId: %lld", LOG_TAG, requestId);

    // Get the environment id from the account service as this is the reference:
    // - If it is not known, it means this is an upgrade from an old version and as soon as the
    //   upgrade is finished, the account service will remember the environmentId.
    // - If it does not match, it means this is a re-installation and we got an old environmentId
    //   from the default preferences and we created a new account with its environmentId.
    //   We must not use and we must drop that old environmentId.
    NSUUID *environmentId = [self.twinlife.accountService environmentId];
    if (!environmentId) {
        environmentId = self.environmentId;
    } else if (!self.environmentId || (self.environmentId && ![environmentId isEqual:self.environmentId])) {
        self.environmentId = environmentId;
        self.mustCleanEnvironment = YES;
    }

    NSMutableDictionary<NSString *, NSString *> *twinlifeConfiguration = [[NSMutableDictionary alloc] init];
    for (TLBaseService *baseService in self.twinlife.twinlifeServices) {
        if ([baseService isServiceOn]) {
            twinlifeConfiguration[SERVICE_NAMES[baseService.serviceConfiguration.baseServiceId]] = baseService.serviceConfiguration.version;
        }
    }
    UIDevice *device = [UIDevice currentDevice];

    NSMutableString *osName = [NSMutableString stringWithCapacity:256];
    [osName appendString:[device systemName]];
    [osName appendString:@"."];
    [osName appendString:[device systemVersion]];

    NSMutableDictionary<NSString *, NSString *> *configs = [[NSMutableDictionary alloc] init];

    // Report the iOS device identifier if this is enabled.
    if ([TLTwinlife MANAGEMENT_REPORT_IOS_ID]) {
        NSMutableString *software = [NSMutableString stringWithCapacity:256];
        NSUUID *deviceIdentifier = [device identifierForVendor];
        if (deviceIdentifier) {
            [software appendString:@"ios-id:"];
            [software appendString:[deviceIdentifier UUIDString]];
        }
        configs[VALIDATE_CONFIGURATION_SOFTWARE] = software;
    }

    // Send the default locale to have the language, country, variant, script and extension.
    NSLocale *currentLocale = [NSLocale currentLocale];

    malloc_statistics_t memStats;
    malloc_zone_statistics(NULL, &memStats);

    TLDeviceInfo *deviceInfo = [self.twinlife getDeviceInfo];
    NSMutableString *power = [NSMutableString stringWithCapacity:256];
    [power appendFormat:@"charging:%d,battery:%.1f,low-power:%d,notifs:%d", deviceInfo.charging, deviceInfo.batteryLevel, deviceInfo.isLowPowerModeEnabled, deviceInfo.allowNotifications];
    [power appendFormat:@",run:%lld:%lld:%ld:%ld:0:0:%ld:0:0", deviceInfo.backgroundTime, deviceInfo.foregroundTime, deviceInfo.alarmCount, deviceInfo.networkLockCount, deviceInfo.pushCount];
    [power appendFormat:@",mem:%d:%zu:%zu", memStats.blocks_in_use, memStats.size_in_use, memStats.size_allocated];
    configs[VALIDATE_CONFIGURATION_POWER_MANAGEMENT] = power;
    
    TLServerConnection *serverConnection = self.twinlife.serverConnection;
    TLConnectionStats *connectionStats = [serverConnection currentConnectionStats];
    TLProxyDescriptor *proxy = [serverConnection currentProxyDescriptor];
    TLErrorStats *errorStats = [serverConnection errorStats];
    NSMutableString *connect = [NSMutableString stringWithCapacity:256];
    if (connectionStats) {
        [connect appendFormat:@"dnsTime:%lld,tcpTime:%lld,tlsTime:%lld,txnTime:%lld", connectionStats.dnsTime, connectionStats.tcpConnectTime, connectionStats.txnResponseTime, connectionStats.txnResponseTime];
    }

    if (errorStats) {
        [connect appendFormat:@",dnsError:%ld,tcpError:%ld,tlsError:%ld,txnError:%ld,proxyError:%ld,tlsHostError:%ld,tlsVerifyError:%ld,wsCount:%ld",
         errorStats.dnsErrorCount, errorStats.tcpErrorCount, errorStats.tlsErrorCount, errorStats.txnErrorCount, errorStats.proxyErrorCount, errorStats.tlsHostErrorCount, errorStats.certificatErrorCount, errorStats.createCounter];
    }
    [connect appendFormat:@",connect:%lld,rtt:%d,drift:%lld", serverConnection.connectCount, self.twinlife.estimatedRTT, self.twinlife.serverTimeCorrection];
    if (proxy) {
        [connect appendFormat:@",proxy:%d", proxy.isUserProxy ? 2 : ([proxy isKindOfClass:[TLSNIProxyDescriptor class]] ? 1 : 3)];
    }
    configs[VALIDATE_CONFIGURATION_CONNECT_STATS] = connect;

    // Add the timezone information.
    NSTimeZone *timezone = [NSTimeZone localTimeZone];
    configs[VALIDATE_CONFIGURATION_TIMEZONE] = [NSString stringWithFormat:@"%li", timezone.secondsFromGMT];

    NSString *capabilities = self.enableAudioVideo ? @"data,voip" : @"data";

    int deviceState;
    switch ([[self.twinlife getJobService] applicationState]) {
        case TLApplicationStateForeground:
        default:
            deviceState = 0;
            break;

        case TLApplicationStateBackground:
            deviceState = 1;
            break;
            
        case TLApplicationStateWakeupPush:
            deviceState = 2;
            break;

        case TLApplicationStateWakeupAlarm:
            deviceState = 3;
            break;
    }

    TLValidateConfigurationIQ *iq = [[TLValidateConfigurationIQ alloc] initWithSerializer:IQ_VALIDATE_CONFIGURATION_SERIALIZER requestId:requestId deviceState:deviceState environmentId:environmentId pushVariant:self.pushNotificationVariant pushToken:self.pushNotificationVoIPToken pushRemoteToken:self.pushNotificationRemoteToken services:twinlifeConfiguration hardwareName:self.twinlife.model osName:osName locale:currentLocale.localeIdentifier capabilities:capabilities configs:configs];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)updateConfigurationWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ updateConfigurationWithRequestId: %lld", LOG_TAG, requestId);

    TLUpdateConfigurationIQ *iq = [[TLUpdateConfigurationIQ alloc] initWithSerializer:IQ_UPDATE_CONFIGURATION_SERIALIZER requestId:requestId environmentId:self.environmentId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (NSData *)notificationKey {
    DDLogVerbose(@"%@ notificationKey", LOG_TAG);
    
    if (!self.environmentId) {
        return [[NSData alloc] init];
    }
    
    NSMutableData *result = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    NSData* data = [[self.environmentId.UUIDString lowercaseString] dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256(data.bytes, (unsigned int)data.length, result.mutableBytes);
    return result;
}

- (void)sendFeedbackWithDescription:(nonnull NSString *)description email:(nonnull NSString *)email subject:(nonnull NSString *)subject logReport:(nullable NSString *)logReport withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode))block {
    DDLogVerbose(@"%@ sendFeedbackWithDescription: %@ email: %@ subject: %@ logReport: %@", LOG_TAG, description, email, subject, logReport);
    
    NSMutableString *deviceDescription = [NSMutableString stringWithCapacity:1024];
    
    // Send the default locale to have the language, country, variant, script and extension.
    NSLocale *currentLocale = [NSLocale currentLocale];
    [deviceDescription appendString:@"Locale: "];
    [deviceDescription appendString:currentLocale.localeIdentifier];
    [deviceDescription appendString:@"\n"];
    
    [deviceDescription appendString:@"OS: "];
    [deviceDescription appendString:[[UIDevice currentDevice] systemName]];
    [deviceDescription appendString:@" "];
    [deviceDescription appendString:[[UIDevice currentDevice] systemVersion]];
    [deviceDescription appendString:@"\n"];
    [deviceDescription appendString:@"Brand: Apple\n"];
    [deviceDescription appendString:@"Model: "];
    [deviceDescription appendString:self.twinlife.model];
    if (logReport) {
        [deviceDescription appendString:@"\nLogReport:\n"];
        
        [deviceDescription appendString:logReport];
    }

    int64_t requestId = [TLTwinlife newRequestId];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = [[TLManagementFeedbackPendingRequest alloc] initWithConsumer:block];
    }
    TLFeedbackIQ *feedback =  [[TLFeedbackIQ alloc] initWithSerializer:IQ_FEEDBACK_SERIALIZER requestId:requestId email:email subject:subject feedbackDescription:description deviceDescription:deviceDescription];
    [self sendBinaryIQ:feedback factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)logEventWithEventId:(NSString *)eventId key:(NSString *)key value:(NSString *)value flush:(BOOL)flush {
    DDLogVerbose(@"%@ logEventWithEventId: %@ value: %@ flush: %@", LOG_TAG, eventId, value, flush ? @"YES" : @"NO");
    
    @synchronized (self) {
        [self.events addObject:[[TLEvent alloc] initWithEventId:eventId key:key value:value]];
    }
    [self sendEvents:flush];
}

- (void)logEventWithEventId:(NSString *)eventId attributes:(NSDictionary *)attributes  flush:(BOOL)flush {
    DDLogVerbose(@"%@ logEventWithEventId: %@ attributes: %@ flush: %@", LOG_TAG, eventId, attributes, flush ? @"YES" : @"NO");
    
    @synchronized (self) {
        [self.events addObject:[[TLEvent alloc]initWithEventId:eventId attributes:attributes]];
    }
    [self sendEvents:flush];
}

- (nonnull NSString *)buildLogReport {
    DDLogVerbose(@"%@ buildLogReport", LOG_TAG);
    
    NSMutableString *dbDump = [self.twinlife.databaseService checkConsistency];

    TLDeviceInfo *deviceInfo = [self.twinlife getDeviceInfo];
    NSMutableString *power = [NSMutableString stringWithCapacity:256];
    [power appendFormat:@"charging:%d,battery:%.1f,low-power:%d", deviceInfo.charging, deviceInfo.batteryLevel, deviceInfo.isLowPowerModeEnabled];
    [power appendFormat:@",run:%lld:%lld:%ld:%ld:0:0:%ld:0:0", deviceInfo.backgroundTime, deviceInfo.foregroundTime, deviceInfo.alarmCount, deviceInfo.networkLockCount, deviceInfo.pushCount];
    [dbDump appendFormat:@"\nPower: %@", power];
    
    TLServerConnection *serverConnection = self.twinlife.serverConnection;
    NSMutableString *connect = [NSMutableString stringWithCapacity:256];
    [connect appendFormat:@"tlsTime:%lld,connect:%lld,rtt:%d,drift:%lld", serverConnection.connectTime, serverConnection.connectCount, self.twinlife.estimatedRTT, self.twinlife.serverTimeCorrection];
    [dbDump appendFormat:@"\nConnection: %@", connect];

    // Add the timezone information.
    NSTimeZone *timezone = [NSTimeZone localTimeZone];
    [dbDump appendFormat:@"\nTimezone: %@", [NSString stringWithFormat:@"%li", timezone.secondsFromGMT]];

    NSDictionary<NSString *, TLServiceStats *> *serviceStats = [self.twinlife getServiceStats];
    for (NSString *name in serviceStats) {
        TLServiceStats *stat = serviceStats[name];
        if (stat && (stat.sendPacketCount > 0 || stat.sendErrorCount > 0 || stat.sendDisconnectedCount > 0 || stat.sendTimeoutCount > 0)) {
            [dbDump appendFormat:@"\n%@: %d:%d:%d:%d", name, stat.sendPacketCount, stat.sendDisconnectedCount, stat.sendErrorCount, stat.sendTimeoutCount];
        }
    }

    [dbDump appendString:@"\n"];
    [dbDump appendString:[self.twinlife getDatabaseDiagnostic]];
    [dbDump appendString:[self.twinlife getOpenedFileDiagnostic]];
    [dbDump appendString:[[self.twinlife getPeerConnectionService] getP2PDiagnostics]];

    return dbDump;
}

- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nullable NSException *)exception vaList:(va_list)vaList {
    DDLogVerbose(@"%@ assertionWithAssertPoint: %@ exception: %@", LOG_TAG, assertPoint, exception);
    
    NSMutableArray<TLAssertValue *> *values = nil;
    while (42) {
        id arg = va_arg(vaList, id);
        if (!arg) {
            break;
        }
        
        if (values == nil) {
            values = [[NSMutableArray alloc] init];
        }

        NSObject *object = (NSObject *)arg;
        if ([object isKindOfClass:[TLAssertValue class]]) {
            [values addObject:(TLAssertValue *)object];
        }
    }

    int64_t timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t requestId = [TLTwinlife newRequestId];
    TLAssertionIQ *assertionIQ = [[TLAssertionIQ alloc] initWithSerializer:IQ_ASSERTION_SERIALIZER requestId:requestId applicationId:self.applicationId applicationVersion:self.applicationVersion assertPoint:assertPoint values:values exception:exception timestamp:timestamp];
    @synchronized (self) {
        // Limit to MAX_ASSERTIONS the number of assertions we can report during the last 5 seconds
        // This is a simplified token bucket algorithm but we want to keep consecutive assertions
        // even if the rate is higher than the limit and fills the 5s time slot completely.
        int64_t dt = timestamp - self.lastDatabaseErrorTime;
        if (dt > 5000L) {
            self.assertionCount = 0;
            self.lastDatabaseErrorTime = timestamp;
        }
        self.assertionCount++;
        if (self.assertionCount > MAX_ASSERTIONS) {
            return;
        }

        // And in case we are not connected, also limit the queue to MAX_ASSERTIONS.
        if (self.pendingAssertions.count > MAX_ASSERTIONS) {
            return;
        }
        [self.pendingAssertions addObject:assertionIQ];
    }
    if (self.signIn) {
        [self flushAssertions];
    }
}

- (void)flushAssertions {
    DDLogVerbose(@"%@ flushAssertions", LOG_TAG);

    while (1) {
        TLAssertionIQ *assertionIQ;
        @synchronized (self) {
            if (self.pendingAssertions.count == 0) {
                return;
            }
            assertionIQ = self.pendingAssertions.lastObject;
            [self.pendingAssertions removeLastObject];
        }

        assertionIQ.applicationId = self.applicationId;
        assertionIQ.applicationVersion = self.applicationVersion;
        NSData *data = [assertionIQ serializeCompactWithSerializerFactory:self.serializerFactory];
        [self.serverStream sendWithData:data];
    }
}

#pragma mark - TLManagementServiceImpl

- (BOOL)hasValidatedConfiguration {
    DDLogVerbose(@"%@ hasValidatedConfiguration", LOG_TAG);
    
    return self.validatedConfiguration;
}

- (void)onValidateConfigurationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onValidateConfigurationWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnValidateConfigurationIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnValidateConfigurationIQ *onValidateConfigurationIQ = (TLOnValidateConfigurationIQ *)iq;

    self.validatedConfiguration = YES;

    [self updateConfigurationWithIQ:onValidateConfigurationIQ];

    // Old environment was retrieved from the user defaults: remove it because it is now in the account service
    // (see onUpdateConfigurationWithConfiguration in TLAccountServiceImpl).
    if (self.mustCleanEnvironment) {
        [self eraseOldEnvironment:[TLTwinlife getAppSharedUserDefaults]];
        [self eraseOldEnvironment:[NSUserDefaults standardUserDefaults]];
        self.mustCleanEnvironment = NO;
    }

    [self.twinlife onTwinlifeOnline];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onValidateConfigurationWithRequestId:)]) {
            id<TLManagementServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onValidateConfigurationWithRequestId:iq.requestId];
            });
        }
    }

    if (self.checkPreviousCrash) {
        self.checkPreviousCrash = NO;

        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:crashFile]) {
            // NSMutableString* content = [NSMutableString stringWithContentsOfFile:crashFile encoding:NSUTF8StringEncoding error:NULL];
            // [self sendProblemReportWithDescription:content exception:nil];

            NSURL *appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
            NSString *prevCrashPath = [appDir URLByAppendingPathComponent:@"twinlife-crash.stamp"].path;
            [fileManager removeItemAtPath:crashFile error:nil];
            [fileManager createFileAtPath:prevCrashPath contents:nil attributes:nil];
        }
    }

    [self flushAssertions];

    // If there are pending events, flush them now.
    if (self.events.count > 0) {
        [self sendEvents:YES];
    }
}

- (void)onUpdateConfigurationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onUpdateConfigurationWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnValidateConfigurationIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnValidateConfigurationIQ *onValidateConfigurationIQ = (TLOnValidateConfigurationIQ *)iq;

    [self updateConfigurationWithIQ:onValidateConfigurationIQ];
}

- (void)onSetPushTokenWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSetPushTokenWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    // Now we know the server has our push token.
    self.setPushNotificationTokenDone = YES;
}

- (void)onLogEventWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onLogEventWithIQ: %@", LOG_TAG, iq);
    
    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    @synchronized (self) {
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
}

- (void)onFeedbackWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onFeedbackWithIQ: %@", LOG_TAG, iq);
    
    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLManagementPendingRequest *pendingRequest;
    @synchronized (self) {
        pendingRequest = [self.pendingRequests objectForKey:lRequestId];
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (pendingRequest && [pendingRequest isKindOfClass:[TLManagementFeedbackPendingRequest class]]) {
        TLManagementFeedbackPendingRequest *feedbackPendingRequest = (TLManagementFeedbackPendingRequest *)pendingRequest;
        feedbackPendingRequest.complete(TLBaseServiceErrorCodeSuccess);
    }
}

- (void)updateConfigurationWithIQ:(nonnull TLOnValidateConfigurationIQ *)iq {
    DDLogVerbose(@"%@ updateConfigurationWithIQ: %@", LOG_TAG, iq);
    
    TLBaseServiceImplConfiguration *configuration = [[TLBaseServiceImplConfiguration alloc] init];
    configuration.turnServers = iq.turnServers;
    configuration.hostnames = iq.hostnames;
    configuration.features = iq.features;
    configuration.environmentId = iq.environmentId;

    if (!self.environmentId) {
        self.environmentId = configuration.environmentId;

    } else if (![self.environmentId isEqual:configuration.environmentId]) {
        TL_ASSERT_EQUAL(self.twinlife, self.environmentId, configuration.environmentId, [TLManagementServiceAssertPoint ENVIRONMENT], TLAssertionParameterEnvironmentId, nil);

        self.environmentId = configuration.environmentId;
    }

    [self setRefreshConfigurationWithTimeout:iq.turnTTL];

    self.configuration = configuration;
    [self.twinlife onUpdateConfigurationWithConfiguration:self.configuration];
}

- (void)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ errorWithErrorCode: %d errorParameter= %@", LOG_TAG, errorCode, errorParameter);
    
    [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:errorCode errorParameter:errorParameter];
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);

    NSNumber *lRequestId = [NSNumber numberWithLongLong:errorPacketIQ.requestId];
    TLManagementPendingRequest *pendingRequest;
    @synchronized (self) {
        pendingRequest = [self.pendingRequests objectForKey:lRequestId];
        if (pendingRequest) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }
    if (!pendingRequest) {
        return;
    } else if ([pendingRequest isKindOfClass:[TLManagementFeedbackPendingRequest class]]) {
        TLManagementFeedbackPendingRequest *feedbackPendingRequest = (TLManagementFeedbackPendingRequest *)pendingRequest;
        feedbackPendingRequest.complete(errorPacketIQ.errorCode);
    } else if ([pendingRequest isKindOfClass:[TLManagementEventsPendingRequest class]] && (errorPacketIQ.errorCode == TLBaseServiceErrorCodeTimeoutError || errorPacketIQ.errorCode == TLBaseServiceErrorCodeTwinlifeOffline)) {
        TLManagementEventsPendingRequest *eventsPendingRequest = (TLManagementEventsPendingRequest *)pendingRequest;

        // Prepare to send again the events if we failed due to network error.
        [self.events addObjectsFromArray:eventsPendingRequest.events];
    }
}

#pragma mark - Private methods

- (void)setPushNotificationToken {
    DDLogVerbose(@"%@ setPushNotificationToken", LOG_TAG);
    
    if (self.setPushNotificationTokenDone) {
        return;
    }
    if (![self isSignIn] || !self.pushNotificationVariant || !self.pushNotificationVoIPToken || !self.environmentId) {
        return;
    }
    
    TLSetPushTokenIQ *iq = [[TLSetPushTokenIQ alloc] initWithSerializer:IQ_SET_PUSH_TOKEN_SERIALIZER requestId:[TLTwinlife newRequestId] environmentId:self.environmentId pushVariant:self.pushNotificationVariant pushToken:self.pushNotificationVoIPToken pushRemoteToken:self.pushNotificationRemoteToken];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)sendEvents:(BOOL)flush {
    DDLogVerbose(@"%@ sendEvents: %d", LOG_TAG, flush);
    
    if (![self.twinlife isTwinlifeOnline]) {
        return;
    }

    NSArray<TLEvent *> *events;
    int64_t requestId;
    @synchronized (self) {
        if (!flush && self.events.count < MAX_EVENTS) {
            return;
        }
        if (self.events.count == 0) {
            return;
        }

        events = self.events;
        requestId = [TLTwinlife newRequestId];
        self.events = [[NSMutableArray alloc] init];
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = [[TLManagementEventsPendingRequest alloc] initWithEvents:events];
    }

    TLLogEventIQ *iq = [[TLLogEventIQ alloc] initWithSerializer:IQ_LOG_EVENT_SERIALIZER requestId:requestId events:events];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)setRefreshConfigurationWithTimeout:(long)ttl {
    DDLogVerbose(@"%@ setRefreshConfigurationWithTimeout: %ld", LOG_TAG, ttl);
    
    if (ttl <= 0) {
        ttl = DEFAULT_TTL;
    } else if (ttl < MIN_UPDATE_TTL) {
        ttl = MIN_UPDATE_TTL;
    }
    
    if (self.refreshJobId) {
        [self.refreshJobId cancel];
        self.refreshJobId = nil;
    }
    if (ttl > 0) {
        self.refreshJobId = [[self.twinlife getJobService] scheduleWithJob:self.managementJob delay:ttl / 2 priority:TLJobPriorityMessage];
    }
}

- (void)runRefreshJob {
    DDLogVerbose(@"%@ runRefreshJob", LOG_TAG);
    
    self.refreshJobId = nil;
    [self setRefreshConfigurationWithTimeout:60];
    [self updateConfigurationWithRequestId:[TLTwinlife newRequestId]];
}

@end
