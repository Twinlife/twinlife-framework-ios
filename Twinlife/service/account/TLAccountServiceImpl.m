/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import "TLAccountServiceImpl.h"

#import "TLAccountServiceSecuredConfiguration.h"
#import "TLTwinlifeSecuredConfiguration.h"
#import "TLBaseServiceImpl.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLCreateAccountIQ.h"
#import "TLDeleteAccountIQ.h"
#import "TLAuthChallengeIQ.h"
#import "TLAuthRequestIQ.h"
#import "TLOnAuthChallengeIQ.h"
#import "TLOnAuthRequestIQ.h"
#import "TLOnCreateAccountIQ.h"
#import "TLCancelFeatureIQ.h"
#import "TLSubscribeFeatureIQ.h"
#import "TLOnSubscribeFeatureIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define ACCOUNT_SERVICE_VERSION @"2.3.1"

#define AUTH_CHALLENGE_SCHEMA_ID               @"91780AB7-016A-463B-9901-434E52C200AE"
#define AUTH_REQUEST_SCHEMA_ID                 @"BF0A6327-FD04-4DFF-998E-72253CFD91E5"
#define CREATE_ACCOUNT_SCHEMA_ID               @"84449ECB-F09F-4C12-A936-038948C2D980"
#define DELETE_ACCOUNT_SCHEMA_ID               @"60e72a89-c1ef-49fa-86a8-0793e5e662e4"
#define SUBSCRIBE_FEATURE_SCHEMA_ID            @"eb420020-e55a-44b0-9e9e-9922ec055407"
#define CANCEL_FEATURE_SCHEMA_ID               @"0B20EF35-A5D9-45F2-9B97-C6B3D15983FA"
#define PONG_SCHEMA_ID                         @"fc0e491c-d91b-43c6-a25c-46d566c788b7"

#define ON_AUTH_CHALLENGE_SCHEMA_ID            @"A5F47729-2FEE-4B38-AC91-3A67F3F9E1B6"
#define ON_AUTH_REQUEST_SCHEMA_ID              @"9CEE4256-D2B7-4DE3-A724-1F61BB1454C8"
#define ON_AUTH_ERROR_SCHEMA_ID                @"ed230b09-b9ff-4d9a-83c9-ddcc3ad686c6"
#define ON_CREATE_ACCOUNT_SCHEMA_ID            @"3D8A1111-61F8-4B27-8229-43DE24A9709B"
#define ON_DELETE_ACCOUNT_SCHEMA_ID            @"48e15279-8070-4c49-a71c-ce876cca579e"
#define ON_SUBSCRIBE_FEATURE_SCHEMA_ID         @"50FEC907-1D63-4617-A099-D495971930EF"
#define ON_CANCEL_FEATURE_SCHEMA_ID            @"34F465EA-A459-423A-A270-2612DC72DAB4"
#define ON_SERVER_PING_SCHEMA_ID               @"fb21d934-f3b4-4432-a82f-0d5a1f17e685"

#define MAX_PASSWORD_LENGTH 32

#define SUBSCRIBE_REQUEST      1
#define CANCEL_REQUEST         2
#define DELETE_ACCOUNT_REQUEST 3

static TLBinaryPacketIQSerializer *IQ_AUTH_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_AUTH_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CREATE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SUBSCRIBE_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CANCEL_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PONG_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_ON_AUTH_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_AUTH_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_AUTH_ERROR_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SUBSCRIBE_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CANCEL_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SERVER_PING_SERIALIZER = nil;

//
// Interface: TLAccountService ()
//

@interface TLAccountService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, NSNumber *> *pendingRequests;
@property BOOL createAccountAllowed;
@property (nullable) TLAuthChallengeIQ *authChallengeIQ;
@property (nullable) TLOnAuthChallengeIQ *onAuthChallengeIQ;
@property (nullable) NSData *serverKey;
@property (nullable) NSUUID *applicationId;
@property (nullable) NSUUID *serviceId;
@property (nullable) NSString *applicationName;
@property (nullable) NSString *applicationVersion;
@property (nullable) NSString *authUser;
@property uint64_t authRequestTime;

- (void)deviceSignIn;

- (void)onAuthChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onAuthRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onCreateAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onDeleteAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)finishDeleteAccountWithRequestId:(int64_t)requestId;

/// Send the raw data after serialization if the websocket is connected (we don't need to be authentified).
- (BOOL)sendBinaryWithRequestId:(int64_t)requestId data:(nonnull NSData *)data timeout:(NSTimeInterval)timeout;

@end

//
// Implementation: TLAccountServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceConfiguration"

@implementation TLAccountServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdAccountService version:[TLAccountService VERSION] serviceOn:NO];
    
    return self;
}

@end

//
// Implementation: TLAccountService
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountService"

@implementation TLAccountService

+ (void)initialize {
    
    IQ_AUTH_CHALLENGE_SERIALIZER = [[TLAuthChallengeIQSerializer alloc] initWithSchema:AUTH_CHALLENGE_SCHEMA_ID schemaVersion:2];
    IQ_AUTH_REQUEST_SERIALIZER = [[TLAuthRequestIQSerializer alloc] initWithSchema:AUTH_REQUEST_SCHEMA_ID schemaVersion:2];
    IQ_CREATE_ACCOUNT_SERIALIZER = [[TLCreateAccountIQSerializer alloc] initWithSchema:CREATE_ACCOUNT_SCHEMA_ID schemaVersion:2];
    IQ_DELETE_ACCOUNT_SERIALIZER = [[TLDeleteAccountIQSerializer alloc] initWithSchema:DELETE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_SUBSCRIBE_FEATURE_SERIALIZER = [[TLSubscribeFeatureIQSerializer alloc] initWithSchema:SUBSCRIBE_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_CANCEL_FEATURE_SERIALIZER = [[TLCancelFeatureIQSerializer alloc] initWithSchema:CANCEL_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_PONG_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:PONG_SCHEMA_ID schemaVersion:1];

    IQ_ON_AUTH_CHALLENGE_SERIALIZER = [[TLOnAuthChallengeIQSerializer alloc] initWithSchema:ON_AUTH_CHALLENGE_SCHEMA_ID schemaVersion:2];
    IQ_ON_AUTH_REQUEST_SERIALIZER = [[TLOnAuthRequestIQSerializer alloc] initWithSchema:ON_AUTH_REQUEST_SCHEMA_ID schemaVersion:2];
    IQ_ON_AUTH_ERROR_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_AUTH_ERROR_SCHEMA_ID schemaVersion:1];
    IQ_ON_CREATE_ACCOUNT_SERIALIZER = [[TLOnCreateAccountIQSerializer alloc] initWithSchema:ON_CREATE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_ACCOUNT_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_DELETE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_ON_SUBSCRIBE_FEATURE_SERIALIZER = [[TLOnSubscribeFeatureIQSerializer alloc] initWithSchema:ON_SUBSCRIBE_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_ON_CANCEL_FEATURE_SERIALIZER = [[TLOnSubscribeFeatureIQSerializer alloc] initWithSchema:ON_CANCEL_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_ON_SERVER_PING_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_SERVER_PING_SCHEMA_ID schemaVersion:1];
}

+ (NSString *)VERSION {
    
    return ACCOUNT_SERVICE_VERSION;
}

+ (nonnull NSData *)xorData:(nonnull NSData *)data1 withData:(nonnull NSData *)data2 {
    NSMutableData *result = data1.mutableCopy;

    char *dataPtr = (char *)result.mutableBytes;

    char *keyData = (char *)data2.bytes;

    char *keyPtr = keyData;
    int keyIndex = 0;

    for (int x = 0; x < data1.length; x++) {
        *dataPtr = *dataPtr ^ *keyPtr;
        dataPtr++;
        keyPtr++;

        if (++keyIndex == data2.length) {
            keyIndex = 0;
            keyPtr = keyData;
        }
    }

    return result;
}

+ (NSData *)createHmacWithAlgorithm:(CCHmacAlgorithm) algorithm data:(NSData *)data key:(NSData *)key {
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];

    CCHmac(algorithm, [key bytes], [key length], [data bytes], [data length], cHMAC);

    return [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
}

+ (NSData *)createSaltedPasswordWithAlgorithm:(CCHmacAlgorithm) algorithm password:(nonnull NSString *)password salt:(nonnull NSData *)saltData iterations:(NSUInteger)rounds {
    NSMutableData *mutableSaltData = [saltData mutableCopy];
    UInt8 zeroHex= 0x00;
    UInt8 oneHex= 0x01;
    NSData *zeroData = [[NSData alloc] initWithBytes:&zeroHex length:sizeof(zeroHex)];
    NSData *oneData = [[NSData alloc] initWithBytes:&oneHex length:sizeof(oneHex)];
    NSData* passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:zeroData];
    [mutableSaltData appendData:oneData];
    
    NSData *result = [TLAccountService createHmacWithAlgorithm:algorithm data:mutableSaltData key:passwordData];
    NSData *previous = [result copy];
    
    for (int i = 1; i < rounds; i++) {
        previous = [TLAccountService createHmacWithAlgorithm:algorithm data:previous key:passwordData];
        result = [TLAccountService xorData:result withData:previous];
    }
    
    return result;
}

#pragma mark - BaseServiceImpl

- (instancetype)initWithTwinlife:(TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    if (self) {
        _allowedFeatures = [[NSMutableSet alloc] init];
        _serializerFactory = twinlife.serializerFactory;
        _pendingRequests = [[NSMutableDictionary alloc] init];

        // Register the binary IQ handlers for the responses.
        [twinlife addPacketListener:IQ_ON_AUTH_CHALLENGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onAuthChallengeWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_AUTH_REQUEST_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onAuthRequestWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_AUTH_ERROR_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onAuthErrorWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_CREATE_ACCOUNT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onCreateAccountWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_ACCOUNT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteAccountWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_SUBSCRIBE_FEATURE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onSubscribeFeatureWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_CANCEL_FEATURE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onSubscribeFeatureWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_SERVER_PING_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onServerPingWithIQ:iq];
        }];
    }
    return self;
}

- (void)configure:(nonnull TLBaseServiceConfiguration*)baseServiceConfiguration applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId {
    DDLogVerbose(@"%@ configure: %@ applicationId: %@ serviceId: %@", LOG_TAG, baseServiceConfiguration, applicationId, serviceId);

    TLAccountServiceConfiguration* accountServiceConfiguration = [[TLAccountServiceConfiguration alloc] init];
    TLAccountServiceConfiguration* serviceConfiguration = (TLAccountServiceConfiguration *) baseServiceConfiguration;
    accountServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    accountServiceConfiguration.defaultAuthenticationAuthority = serviceConfiguration.defaultAuthenticationAuthority;
    self.serviceConfiguration = accountServiceConfiguration;

    self.createAccountAllowed = serviceConfiguration.defaultAuthenticationAuthority == TLAccountServiceAuthenticationAuthorityDevice;

    self.applicationId = applicationId;
    self.serviceId = serviceId;

    self.configured = YES;
    self.serviceOn = serviceConfiguration.isServiceOn;

    // Load the secure configuration now so that the ManagementService can get the environmentId.
    [self loadSecureConfiguration];
}

- (void)loadSecureConfiguration {
    DDLogVerbose(@"%@ loadSecureConfiguration", LOG_TAG);

    @synchronized (self) {
        if (self.securedConfiguration) {

            return;
        }

        self.securedConfiguration = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:self.twinlife.serializerFactory alternateApplication:NO];
        if (!self.securedConfiguration || self.twinlife.isInstalled) {
            self.securedConfiguration = [[TLAccountServiceSecuredConfiguration alloc] initWithSerializerFactory:self.twinlife.serializerFactory deviceIdentifier:self.twinlife.twinlifeSecuredConfiguration.deviceIdentifier];
        }

        if (self.securedConfiguration.subscribedFeatures) {
            NSArray<NSString *> *featureList = [self.securedConfiguration.subscribedFeatures componentsSeparatedByString: @","];
            [self.allowedFeatures addObjectsFromArray:featureList];
        }
    }
}

- (BOOL)isAccountDisabled {
    DDLogVerbose(@"%@ isAccountDisabled", LOG_TAG);

    TLAccountServiceSecuredConfiguration *securedConfiguration;
    @synchronized (self) {
        securedConfiguration = self.securedConfiguration;
    }

    // Load the secured configuration as a temporary configuration.
    if (!securedConfiguration) {
        securedConfiguration = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:self.twinlife.serializerFactory alternateApplication:NO];
    }
    return securedConfiguration.authenticationAuthority == TLAccountServiceAuthenticationAuthorityDisabled;
}

- (nullable NSString *)user {

    return self.authUser;
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);

    @synchronized (self) {
        self.securedConfiguration = nil;
    }
}

- (void)onTwinlifeResume {
    DDLogVerbose(@"%@: onTwinlifeResume", LOG_TAG);
    
    if (!self.serviceOn) {
        return;
    }
    
    // Reload the secure configuration because it could have been disabled by importApplicationData.
    [self loadSecureConfiguration];
}

- (void)onConnect {
    DDLogVerbose(@"%@: onConnect", LOG_TAG);
    
    [super onConnect];
    
    if (self.isReconnectable)  {
        switch (self.securedConfiguration.authenticationAuthority) {
            case TLAccountServiceAuthenticationAuthorityDevice: {
                [self deviceSignIn];
                //DDLogError(@"%@: onConnect now connected, deviceSignIn disabled", LOG_TAG);
                break;
            }
  
            case TLAccountServiceAuthenticationAuthorityUnregistered: {
                // Explicitly create the account for the first time, once the account is created the
                // authenticate authority will change to DEVICE.
                if (self.createAccountAllowed) {
                    [self createAccountWithRequestId:[TLTwinlife newRequestId] etoken:@""];
                }
                break;
            }

            case TLAccountServiceAuthenticationAuthorityDisabled: {
                // This account has been deleted and we have no way to authenticate nor recover.
                
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onSignInErrorWithErrorCode:)]) {
                        id<TLAccountServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onSignInErrorWithErrorCode:TLBaseServiceErrorCodeAccountDeleted];
                        });
                    }
                }
                break;
            }

            default:
                break;
        }
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@: onDisconnect", LOG_TAG);
    
    // Erase sensitive information in case an authentication has not finished.
    self.onAuthChallengeIQ = nil;
    self.authChallengeIQ = nil;
    self.serverKey = nil;
    [super onDisconnect];
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    [super onSignIn];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSignIn)]) {
            id<TLAccountServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onSignIn];
            });
        }
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [super onSignOut];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSignOut)]) {
            id<TLAccountServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onSignOut];
            });
        }
    }
}

- (void)onUpdateConfigurationWithConfiguration:(TLBaseServiceImplConfiguration *)configuration {
    DDLogVerbose(@"%@ onUpdateConfigurationWithConfiguration: %@", LOG_TAG, configuration);

    NSString *features = configuration.features;
    NSUUID *environmentId = configuration.environmentId;

    if (![self.securedConfiguration isUpdatedWithEnvironmentId:environmentId] && ![self.securedConfiguration isUpdatedWithSubscribedFeatures:features]) {

        return;
    }

    // When the allowed features or the environment is defined, update the list.
    @synchronized (self) {
        if (environmentId) {
            self.securedConfiguration.environmentId = environmentId;
        }
        self.securedConfiguration.subscribedFeatures = features;
        [self.allowedFeatures removeAllObjects];
        if (features) {
            NSArray<NSString *> *featureList = [features componentsSeparatedByString: @","];
            [self.allowedFeatures addObjectsFromArray:featureList];
        }

        // Save so that we can restore a default subscribedFeatures list when we don't have the network.
        [self.securedConfiguration synchronize];
    }
}

#pragma mark - TLAccountService

- (TLAccountServiceAuthenticationAuthority)getAuthenticationAuthority {
    DDLogVerbose(@"%@ getAuthenticationAuthority", LOG_TAG);
    
    if (!self.serviceOn) {
        return TLAccountServiceAuthenticationAuthorityDisabled;
    }
    
    return self.securedConfiguration.authenticationAuthority;
}

- (BOOL)isReconnectable {
    DDLogVerbose(@"%@ isReconnectable", LOG_TAG);
    
    if (!self.serviceOn) {
        return NO;
    }
    
    switch (self.securedConfiguration.authenticationAuthority) {
        case TLAccountServiceAuthenticationAuthorityDevice:
            return !self.securedConfiguration.isSignOut;

        case TLAccountServiceAuthenticationAuthorityUnregistered:
            return YES;

        default:
            return NO;
    }
}

- (BOOL)isFeatureSubscribedWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ isFeatureSubscribedWithName: %@", LOG_TAG, name);

    @synchronized (self) {
        return [self.allowedFeatures containsObject:name];
    }
}

- (void)signOut {
    DDLogVerbose(@"%@ signOut", LOG_TAG);
    
    if (!self.serviceOn) {
        return;
    }
    
    @synchronized(self) {
        self.securedConfiguration.authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
        [self.securedConfiguration synchronize];
        self.authUser = nil;
    }
    
    [self.twinlife onSignOut];
}

- (void)createAccountWithRequestId:(int64_t)requestId etoken:(nullable NSString *)etoken {
    DDLogVerbose(@"%@ createAccountWithRequestId: %lld etoken: %@", LOG_TAG, requestId, etoken);

    if (!self.serviceOn) {
        return;
    }

    // createAccount is allowed if we are not registered yet.
    NSString *username;
    NSString *password;
    @synchronized (self) {
        username = [self.securedConfiguration deviceUsername];
        password = [self.securedConfiguration devicePassword];
        
        if ([self.securedConfiguration authenticationAuthority] != TLAccountServiceAuthenticationAuthorityUnregistered || !username || !password) {
            
            [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNotAuthorizedOperation errorParameter:nil];
            return;
        }
    }

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:username];
    NSString *twinlifeAccessToken = [[NSBundle mainBundle] bundleIdentifier];
    TLCreateAccountIQ *iq = [[TLCreateAccountIQ alloc] initWithSerializer:IQ_CREATE_ACCOUNT_SERIALIZER requestId:requestId applicationId:self.applicationId serviceId:self.serviceId apiKey:self.twinlife.twinlifeConfiguration.apiKey accessToken:twinlifeAccessToken applicationName:self.applicationName applicationVersion:self.applicationVersion twinlifeVersion:TWINLIFE_VERSION accountIdentifier:accountIdentifier accountPassword:password authToken:etoken];

    // We must use a send packet that does not check we are authentified
    // And send as a raw IQ.
    NSData *data = [iq serializeWithSerializerFactory:self.serializerFactory];

    if (![self sendBinaryWithRequestId:iq.requestId data:data timeout:DEFAULT_REQUEST_TIMEOUT]) {

        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        return;
    }
}

- (void)deleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ deleteAccountWithRequestId: %lld", LOG_TAG, requestId);
    
    if (!self.serviceOn) {
        return;
    }

    // Check that the account information we have is valid, if not proceed with the deletion.
    NSString *username;
    NSString *password;
    @synchronized (self) {
        username = [self.securedConfiguration deviceUsername];
        password = [self.securedConfiguration devicePassword];
    }

    // Check that the account information we have is valid, if not proceed with the deletion.
    if (!username || !password || ![self isReconnectable]) {

        [self finishDeleteAccountWithRequestId:requestId];
        return;
    }

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:username];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:DELETE_ACCOUNT_REQUEST];
    }

    TLDeleteAccountIQ *iq = [[TLDeleteAccountIQ alloc] initWithSerializer:IQ_DELETE_ACCOUNT_SERIALIZER requestId:requestId accountIdentifier:accountIdentifier accountPassword:password];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)subscribeFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseProductId:(nonnull NSString *)purchaseProductId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {
    DDLogVerbose(@"%@ subscribeFeatureWithRequestId: %lld merchantId: %d purchaseProductId: %@ purchaseToken: %@ purchaseOrderId: %@", LOG_TAG, requestId, merchantId, purchaseProductId, purchaseToken, purchaseOrderId);
    
    if (!self.serviceOn) {
        return;
    }

    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:SUBSCRIBE_REQUEST];
    }

    TLSubscribeFeatureIQ *iq = [[TLSubscribeFeatureIQ alloc] initWithSerializer:IQ_SUBSCRIBE_FEATURE_SERIALIZER requestId:requestId merchantId:merchantId purchaseProductId:purchaseProductId purchaseToken:purchaseToken purchaseOrderId:purchaseOrderId];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)cancelFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {
    DDLogVerbose(@"%@ cancelFeatureWithRequestId: %lld merchantId: %d purchaseToken: %@ purchaseOrderId: %@", LOG_TAG, requestId, merchantId, purchaseToken, purchaseOrderId);
    
    if (!self.serviceOn) {
        return;
    }

    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:CANCEL_REQUEST];
    }

    TLCancelFeatureIQ *iq = [[TLCancelFeatureIQ alloc] initWithSerializer:IQ_CANCEL_FEATURE_SERIALIZER requestId:requestId merchantId:merchantId purchaseToken:purchaseToken purchaseOrderId:purchaseOrderId];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (nullable NSUUID *)environmentId {
    DDLogVerbose(@"%@ environmentId", LOG_TAG);

    return self.securedConfiguration.environmentId;
}

#pragma mark - TLAccountService IQ

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);

    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    NSNumber *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (request != nil) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }

    // If we have a pending request, this is a subscribe, cancel or delete account and we report the error.
    if (request != nil) {
        if (request.intValue == DELETE_ACCOUNT_REQUEST) {
            [self onErrorWithRequestId:requestId errorCode:errorCode errorParameter:nil];
        } else {
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onSubscribeUpdateWithRequestId:errorCode:)]) {
                    id<TLAccountServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onSubscribeUpdateWithRequestId:requestId errorCode:errorCode];
                    });
                }
            }
        }
        return;
    }
}

- (void)onAuthChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAuthChallengeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnAuthChallengeIQ class]]) {
        return;
    }

    uint64_t receiveTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    [self receivedBinaryIQ:iq];

    // Verify that this is our challenge request.
    if (!self.authChallengeIQ || self.authChallengeIQ.requestId != iq.requestId) {

        self.authChallengeIQ = nil;
        self.authUser = nil;
        [self.serverStream disconnect];
        return;
    }

    // Make sure we have the password, if not abort this authentication.
    NSString *password = self.securedConfiguration.devicePassword;
    if (!password) {

        self.authChallengeIQ = nil;
        self.authUser = nil;
        [self.serverStream disconnect];
        return;
    }

    // Truncate the password because old devices registered with a password > 32 chars but it was truncated by the server.
    // If we continue using that full password, the authentication will fail!
    if (password.length > MAX_PASSWORD_LENGTH) {
        NSRange passwordMaxRange = {0, MAX_PASSWORD_LENGTH};
        password = [password substringWithRange:passwordMaxRange];
    }

    self.onAuthChallengeIQ = (TLOnAuthChallengeIQ *)iq;

    // Build the auth message that must be signed.
    NSString *resource = self.twinlife.resource;
    NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [self.authChallengeIQ clientFirstMessageBare], [self.onAuthChallengeIQ serverFirstMessageBare], resource];

    // Compute everything according to RFC 5802 section 3. SCRAM Algorithm Overview
    NSData *saltedPasswordData = [TLAccountService createSaltedPasswordWithAlgorithm:kCCHmacAlgSHA1 password:password salt:self.onAuthChallengeIQ.salt iterations:self.onAuthChallengeIQ.iterations];
    
    NSData *clientKeyData = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Client Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    unsigned char result[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1([clientKeyData bytes], (CC_LONG)[clientKeyData length], result);
    NSData *storedKeyData = [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];

    NSData *clientSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:storedKeyData];

    // Compute the server key for last step server signature verification.
    self.serverKey = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Server Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    // Create the client proof to send.
    NSData *clientProof = [TLAccountService xorData:clientKeyData withData:clientSignature];

    int64_t deviceTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    uint64_t sendTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    self.authRequestTime = sendTime;
    int deviceState = 0;
    int deviceLatency = (int) ((sendTime - receiveTime) / 1000000L);

    TLAuthRequestIQ *authRequestIQ = [[TLAuthRequestIQ alloc] initWithSerializer:IQ_AUTH_REQUEST_SERIALIZER requestId:[TLTwinlife newRequestId] accountIdentifier:self.authChallengeIQ.accountIdentifier resourceIdentifier:resource deviceNonce:self.authChallengeIQ.nonce deviceProof:clientProof deviceState:deviceState deviceLatency:deviceLatency deviceTimestamp:deviceTimestamp serverTimestamp:self.onAuthChallengeIQ.serverTimestamp];

    // Serialize with the default binary encoder.
    NSData *data = [authRequestIQ serializeWithSerializerFactory:self.serializerFactory];

    if (![self sendBinaryWithRequestId:authRequestIQ.requestId data:data timeout:DEFAULT_REQUEST_TIMEOUT]) {
        self.authChallengeIQ = nil;
        self.onAuthChallengeIQ = nil;
        self.serverKey = nil;
        [self.serverStream disconnect];
        return;
    }
}

- (void)onAuthRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAuthRequestWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnAuthRequestIQ class]]) {
        return;
    }
    
    uint64_t receiveTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    int64_t deviceTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    [self receivedBinaryIQ:iq];

    TLOnAuthRequestIQ *onAuthRequestIQ = (TLOnAuthRequestIQ *)iq;
    NSData *serverSignature = nil;

    // Build the auth message that must be signed.
    if (self.onAuthChallengeIQ && self.serverKey) {
        NSString *resource = self.twinlife.resource;
        NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [self.authChallengeIQ clientFirstMessageBare], [self.onAuthChallengeIQ serverFirstMessageBare], resource];

        serverSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:self.serverKey];
    }
    NSString *authUser = self.authChallengeIQ.accountIdentifier;
    self.onAuthChallengeIQ = nil;
    self.authChallengeIQ = nil;
    self.serverKey = nil;

    // Verify the server signature.
    if (!serverSignature || ![serverSignature isEqualToData:onAuthRequestIQ.serverSignature]) {

        [self.serverStream disconnect];
        return;
    }

    self.authUser = authUser;
    [self.twinlife adjustTimeWithServerTime:onAuthRequestIQ.serverTimestamp deviceTime:deviceTimestamp serverLatency:onAuthRequestIQ.serverLatency requestTime:(receiveTime - self.authRequestTime) / 1000000L];
    [self.twinlife onSignIn];
}

- (void)onAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAuthErrorWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLBinaryErrorPacketIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLBinaryErrorPacketIQ *errorPacketIQ = (TLBinaryErrorPacketIQ *)iq;

    self.authChallengeIQ = nil;
    self.onAuthChallengeIQ = nil;
    self.serverKey = nil;
    self.authUser = nil;
    
    switch (errorPacketIQ.errorCode) {
        // Application id, service id, api key are not recognized: user must uninstall.
        case TLBaseServiceErrorCodeBadRequest:
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onSignInErrorWithErrorCode:)]) {
                    id<TLAccountServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onSignInErrorWithErrorCode:TLBaseServiceErrorCodeWrongLibraryConfiguration];
                    });
                }
            }
            // Keep the web socket connection opened (otherwise we will re-connect again and again).
            return;

        // User account has been deleted: user must uninstall.
        case TLBaseServiceErrorCodeItemNotFound:
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onSignInErrorWithErrorCode:)]) {
                    id<TLAccountServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onSignInErrorWithErrorCode:TLBaseServiceErrorCodeAccountDeleted];
                    });
                }
            }
            // Keep the web socket connection opened (otherwise we will re-connect again and again).
            return;

        // Oops from the server, close and try again.
        case TLBaseServiceErrorCodeServerError:
        case TLBaseServiceErrorCodeNotAuthorizedOperation:
        case TLBaseServiceErrorCodeLimitReached:
        default:
            [self.serverStream disconnect];
            break;
    }
}

- (void)onCreateAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateAccountWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnCreateAccountIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnCreateAccountIQ *onCreateAccountIQ = (TLOnCreateAccountIQ *)iq;

    // Account is now created, setup and save the new authentication authority.
    @synchronized(self) {
        self.securedConfiguration.authenticationAuthority = TLAccountServiceAuthenticationAuthorityDevice;
        self.securedConfiguration.environmentId = onCreateAccountIQ.environmentId;
        [self.securedConfiguration synchronize];
    }

    dispatch_async([self.twinlife twinlifeQueue], ^{
        [self deviceSignIn];
    });

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateAccountWithRequestId:)]) {
            id<TLAccountServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onCreateAccountWithRequestId:iq.requestId];
            });
        }
    }
}

- (void)onDeleteAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteAccountWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    [self finishDeleteAccountWithRequestId:iq.requestId];
}

- (void)onSubscribeFeatureWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSubscribeFeatureWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnSubscribeFeatureIQ class]]) {
        return;
    }
    
    TLOnSubscribeFeatureIQ *onSubscribeFeatureIQ = (TLOnSubscribeFeatureIQ *)iq;
    int64_t requestId = onSubscribeFeatureIQ.requestId;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    [self receivedBinaryIQ:iq];
    @synchronized (self) {
        if (self.pendingRequests[lRequestId] == nil) {

            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    TLBaseServiceErrorCode errorCode = onSubscribeFeatureIQ.errorCode;
    NSString *features = onSubscribeFeatureIQ.features;

    if ([self.securedConfiguration isUpdatedWithSubscribedFeatures:features]) {

        // When the allowed features is changed, update the list.
        @synchronized (self) {
            self.securedConfiguration.subscribedFeatures = features;
            [self.allowedFeatures removeAllObjects];

            NSArray<NSString *> *featureList = [features componentsSeparatedByString: @","];
            [self.allowedFeatures addObjectsFromArray:featureList];

            // Save so that we can restore a default subscribedFeatures list when we don't have the network.
            [self.securedConfiguration synchronize];
        }
    }

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSubscribeUpdateWithRequestId:errorCode:)]) {
            id<TLAccountServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onSubscribeUpdateWithRequestId:requestId errorCode:errorCode];
            });
        }
    }
}

- (void)onServerPingWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onServerPingWithIQ: %@", LOG_TAG, iq);

    TLBinaryPacketIQ *pong = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_PONG_SERIALIZER iq:iq];

    [self sendResponseIQ:pong factory:self.serializerFactory];
}

#pragma mark - private methods

- (void)deviceSignIn {
    DDLogVerbose(@"%@ deviceSignIn", LOG_TAG);
    
    if (!self.serviceOn) {
        return;
    }
    if (!self.applicationId || !self.serviceId) {
        return;
    }

    // Generate nonce for the authentication challenge.
    void *nonceData = malloc(32);
    if (!nonceData) {
        return;
    }
    int result = SecRandomCopyBytes(kSecRandomDefault, 32, nonceData);
    if (result != errSecSuccess) {
        free(nonceData);
        return;
    }

    NSData *deviceNonce = [[NSData alloc] initWithBytesNoCopy:nonceData length:32];

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:self.securedConfiguration.deviceUsername];
    NSString *twinlifeAccessToken = [[NSBundle mainBundle] bundleIdentifier];
    self.authChallengeIQ = [[TLAuthChallengeIQ alloc] initWithSerializer:IQ_AUTH_CHALLENGE_SERIALIZER requestId:[TLTwinlife newRequestId] applicationId:self.applicationId serviceId:self.serviceId apiKey:self.twinlife.twinlifeConfiguration.apiKey accessToken:twinlifeAccessToken applicationName:self.twinlife.twinlifeConfiguration.applicationName applicationVersion:self.twinlife.twinlifeConfiguration.applicationVersion twinlifeVersion:[TLTwinlife VERSION] accountIdentifier:accountIdentifier nonce:deviceNonce];

    // And send as a raw IQ.
    NSData *data = [self.authChallengeIQ serializeWithSerializerFactory:self.serializerFactory];

    if (![self sendBinaryWithRequestId:self.authChallengeIQ.requestId data:data timeout:DEFAULT_REQUEST_TIMEOUT]) {

        self.authChallengeIQ = nil;
        return;
    }
}

- (void)finishDeleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ finishDeleteAccountWithRequestId: %lld", LOG_TAG, requestId);

    // Erase keystore before running the onSignOut() callbacks because one of them may exit the application.
    @synchronized(self) {
        [self.securedConfiguration erase];
    }

    [self.twinlife onSignOut];
    
    // Disable this service to prevent re-loading and re-creating a new account
    // because it happens that the iOS background scheduler can wakeup the application.
    // The user has to stop the application and launch it again.
    self.serviceOn = NO;

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteAccountWithRequestId:)]) {
            id<TLAccountServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteAccountWithRequestId:requestId];
            });
        }
    }
}

- (BOOL)sendBinaryWithRequestId:(int64_t)requestId data:(nonnull NSData *)data timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@: sendBinaryWithRequestId: %lld data: %@ timeout: %f", LOG_TAG, requestId, data, timeout);
    
    if (![self.serverStream isOpened]) {

        return NO;
    }

    [self packetTimeout:requestId timeout:timeout isBinary:YES];

    // And send as a raw IQ.
    [self.serverStream sendWithData:data];
    return YES;
}

@end
