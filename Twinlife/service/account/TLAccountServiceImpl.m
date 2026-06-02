/*
 *  Copyright (c) 2014-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
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
#import "TLTerminateAccountRestoreIQ.h"
#import "TLCryptoServiceImpl.h"
#import "TLGenerateBackupKeyIQ.h"
#import "TLOnGenerateBackupKeyIQ.h"
#import "TLOnGetAllBackupsIQ.h"
#import "TLRestoreChallengeIQ.h"
#import "TLRestoreRequestIQ.h"
#import "TLOnTerminateAccountRestoreIQ.h"
#import "TLBackupService.h"

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
#define TERMINATE_ACCOUNT_RESTORE_SCHEMA_ID    @"2810fd0c-3973-41f3-912b-57872d881b2d"
#define GENERATE_BACKUP_KEY_SCHEMA_ID          @"3d6cef13-f703-415c-bb5c-38459d8e32e1"
#define GENERATE_RESTORE_KEY_SCHEMA_ID         @"acbdbf61-c43f-48e6-a0bc-17ebf11aed1e"
#define GET_ALL_BACKUPS_SCHEMA_ID              @"b2598bed-cce1-421e-8723-57b0a20564b2"
#define DELETE_BACKUPS_SCHEMA_ID               @"07e5a262-59c5-486c-a6f7-d3e72dcdcd91"
#define RESTORE_CHALLENGE_SCHEMA_ID            @"093b4e5c-3040-48d1-9981-cb1f20c16d89"
#define RESTORE_REQUEST_SCHEMA_ID              @"8576bcf4-5901-4e54-b5d5-7e3b70622a7f"

#define ON_AUTH_CHALLENGE_SCHEMA_ID            @"A5F47729-2FEE-4B38-AC91-3A67F3F9E1B6"
#define ON_AUTH_REQUEST_SCHEMA_ID              @"9CEE4256-D2B7-4DE3-A724-1F61BB1454C8"
#define ON_AUTH_ERROR_SCHEMA_ID                @"ed230b09-b9ff-4d9a-83c9-ddcc3ad686c6"
#define ON_CREATE_ACCOUNT_SCHEMA_ID            @"3D8A1111-61F8-4B27-8229-43DE24A9709B"
#define ON_DELETE_ACCOUNT_SCHEMA_ID            @"48e15279-8070-4c49-a71c-ce876cca579e"
#define ON_SUBSCRIBE_FEATURE_SCHEMA_ID         @"50FEC907-1D63-4617-A099-D495971930EF"
#define ON_CANCEL_FEATURE_SCHEMA_ID            @"34F465EA-A459-423A-A270-2612DC72DAB4"
#define ON_SERVER_PING_SCHEMA_ID               @"fb21d934-f3b4-4432-a82f-0d5a1f17e685"
#define ON_GENERATE_BACKUP_KEY_SCHEMA_ID       @"e5ac97e6-bf8b-4054-9115-17edaee8de83"
#define ON_GET_ALL_BACKUPS_SCHEMA_ID           @"088b1c90-f9ea-4d1b-8be3-00d6e9b3afe8"
#define ON_DELETE_BACKUPS_SCHEMA_ID            @"ce07c381-45f1-425d-8f68-2dad60f51052"
#define ON_TERMINATE_RESTORE_SCHEMA_ID         @"a9945fd0-7f68-42ea-8b41-f6bc4d22cfb4"
#define ON_RESTORE_CHALLENGE_SCHEMA_ID         @"caccd8d7-67a8-4868-ae79-af9504cc1f54"
#define ON_RESTORE_CHALLENGE_ERROR_SCHEMA_ID   @"601d27bb-8cff-4cbb-9194-637b52ac6b07"
#define ON_RESTORE_REQUEST_SCHEMA_ID           @"cb6ec9af-8af9-4cea-9b84-b62a1f757f59"
#define ON_RESTORE_REQUEST_ERROR_SCHEMA_ID     @"8687513b-c783-40a3-95e4-70edcd9a5fb1"

#define MAX_PASSWORD_LENGTH 32

#define SUBSCRIBE_REQUEST                   1
#define CANCEL_REQUEST                      2
#define DELETE_ACCOUNT_REQUEST              3
#define GENERATE_BACKUP_PASSWORD_REQUEST    4
#define GET_ALL_BACKUPS_REQUEST             5
#define DELETE_BACKUPS_REQUEST              6
#define AUTH_CHALLENGE_REQUEST              7
#define AUTH_REQUEST_REQUEST                8
#define RESTORE_CHALLENGE_REQUEST           9
#define RESTORE_REQUEST_REQUEST             10
#define TERMINATE_RESTORE_REQUEST           11
#define CHANGE_PASSWORD_REQUEST             12


static TLBinaryPacketIQSerializer *IQ_AUTH_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_AUTH_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CREATE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SUBSCRIBE_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CANCEL_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PONG_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TERMINATE_ACCOUNT_RESTORE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GENERATE_BACKUP_KEY_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GENERATE_RESTORE_KEY_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GET_ALL_BACKUPS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_BACKUPS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_RESTORE_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_RESTORE_REQUEST_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_ON_AUTH_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_AUTH_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_AUTH_ERROR_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_ACCOUNT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SUBSCRIBE_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CANCEL_FEATURE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SERVER_PING_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GENERATE_BACKUP_KEY_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_ALL_BACKUPS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_BACKUPS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_TERMINATE_RESTORE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_RESTORE_CHALLENGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_RESTORE_CHALLENGE_ERROR_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_RESTORE_REQUEST_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_RESTORE_REQUEST_ERROR_SERIALIZER = nil;

static NSSet<NSNumber *> *AUTH_REQUEST_KINDS = nil;

//
// Interface: TLAccountService ()
//

@interface TLAccountService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLAccountPendingRequest *> *pendingRequests;
@property BOOL createAccountAllowed;
@property (nullable) NSUUID *applicationId;
@property (nullable) NSUUID *serviceId;
@property (nullable) NSString *authUser;

- (nullable TLAccountServiceSecuredConfiguration *)activeSecuredConfiguration;

- (void)deviceSignIn;

- (void)onAuthChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onAuthRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onCreateAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onDeleteAccountWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onGenerateBackupKeyWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onGetAllBackupsWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onDeleteBackupsWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onOnRestoreChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onOnRestoreRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onRestoreAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onOnTerminateRestoreWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)finishDeleteAccountWithRequestId:(int64_t)requestId;

/// Send the raw data after serialization if the websocket is connected (we don't need to be authentified).
- (BOOL)sendBinaryWithRequestId:(int64_t)requestId data:(nonnull NSData *)data timeout:(NSTimeInterval)timeout;

@end


@implementation TLAccountPendingRequest

- (nonnull instancetype)initWithRequestKind:(int)requestKind {
    self = [super init];
    
    if (self) {
        _requestKind = requestKind;
    }
    return self;
}

@end

@implementation TLConsumerAccountPendingRequest


- (nonnull instancetype)initWithRequestKind:(int)requestKind consumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:requestKind];
    
    if (self) {
        _consumer = consumer;
    }
    
    return self;
}

@end

@implementation TLAuthChallengePendingRequest

- (nonnull instancetype)initWithAuthChallengeIQ:(nonnull TLAuthChallengeIQ *)authChallengeIQ {
    self = [super initWithRequestKind:AUTH_CHALLENGE_REQUEST];
    
    if (self) {
        _authChallengeIQ = authChallengeIQ;
    }
    
    return self;
}

@end

@implementation TLAuthRequestPendingRequest

- (nonnull instancetype)initWithAuthChallengeIQ:(nonnull TLAuthChallengeIQ *)authChallengeIQ onAuthChallengeIQ:(nonnull TLOnAuthChallengeIQ *)onAuthChallengeIQ serverKey:(nonnull NSData *)serverKey authRequestTime:(int64_t)authRequestTime {
    
    self = [super initWithRequestKind:AUTH_REQUEST_REQUEST];
    
    if (self) {
        _authChallengeIQ = authChallengeIQ;
        _onAuthChallengeIQ = onAuthChallengeIQ;
        _serverKey = serverKey;
        _authRequestTime = authRequestTime;
    }
    
    return self;
}

@end

@implementation TLChangePasswordPendingRequest

- (nonnull instancetype)initWithDevicePassword:(nonnull NSString *)devicePassword {
    self = [super initWithRequestKind:CHANGE_PASSWORD_REQUEST];
    
    if (self) {
        _devicePassword = devicePassword;
    }
    
    return self;
}

@end

@implementation TLGenerateBackupPasswordPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:GENERATE_BACKUP_PASSWORD_REQUEST consumer:consumer];
    
    return self;
}

@end

@implementation TLGetAllBackupsPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:GET_ALL_BACKUPS_REQUEST consumer:consumer];
    
    return self;
}

@end

@implementation TLDeleteBackupsPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:DELETE_BACKUPS_REQUEST consumer:consumer];
    
    return self;
}

@end

@implementation TLTerminateRestorePendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:TERMINATE_RESTORE_REQUEST consumer:consumer];
    
    return self;
}

@end

@implementation TLRestoreChallengePendingRequest

- (nonnull instancetype)initWithAccountSecuredConfiguration:(nonnull TLAccountServiceSecuredConfiguration *)accountSecuredConfiguration restoreChallengeIQ:(nonnull TLRestoreChallengeIQ *)restoreChallengeIQ consumer:(nonnull ConsumerBlock)consumer {
    self = [super initWithRequestKind:RESTORE_CHALLENGE_REQUEST consumer:consumer];
    
    if (self) {
        _accountSecuredConfiguration = accountSecuredConfiguration;
        _restoreChallengeIQ = restoreChallengeIQ;
    }
    
    return self;
}

@end

@implementation TLRestoreRequestPendingRequest

- (nonnull instancetype)initWithRestoreChallengePendingRequest:(nonnull TLRestoreChallengePendingRequest *)restoreChallengePendingRequest onRestoreChallengeIQ:(nonnull TLOnAuthChallengeIQ *)onRestoreChallengeIQ serverKey:(nonnull NSData *)serverKey {
    self = [super initWithRequestKind:RESTORE_REQUEST_REQUEST consumer:restoreChallengePendingRequest.consumer];
    
    if (self) {
        _restoreChallengeIQ = restoreChallengePendingRequest.restoreChallengeIQ;
        _onRestoreChallengeIQ = onRestoreChallengeIQ;
        _serverKey = serverKey;
        _accountSecuredConfiguration = restoreChallengePendingRequest.accountSecuredConfiguration;
    }
    
    return self;
}

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
    IQ_AUTH_REQUEST_SERIALIZER = [[TLAuthRequestIQSerializer alloc] initWithSchema:AUTH_REQUEST_SCHEMA_ID schemaVersion:3];
    IQ_CREATE_ACCOUNT_SERIALIZER = [[TLCreateAccountIQSerializer alloc] initWithSchema:CREATE_ACCOUNT_SCHEMA_ID schemaVersion:2];
    IQ_DELETE_ACCOUNT_SERIALIZER = [[TLDeleteAccountIQSerializer alloc] initWithSchema:DELETE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_SUBSCRIBE_FEATURE_SERIALIZER = [[TLSubscribeFeatureIQSerializer alloc] initWithSchema:SUBSCRIBE_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_CANCEL_FEATURE_SERIALIZER = [[TLCancelFeatureIQSerializer alloc] initWithSchema:CANCEL_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_PONG_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:PONG_SCHEMA_ID schemaVersion:1];
    IQ_TERMINATE_ACCOUNT_RESTORE_SERIALIZER = [[TLTerminateAccountRestoreIQSerializer alloc] initWithSchema:TERMINATE_ACCOUNT_RESTORE_SCHEMA_ID schemaVersion:1];
    IQ_GENERATE_BACKUP_KEY_SERIALIZER = [[TLGenerateBackupKeyIQSerializer alloc] initWithSchema:GENERATE_BACKUP_KEY_SCHEMA_ID schemaVersion:1];
    IQ_GENERATE_RESTORE_KEY_SERIALIZER = [[TLGenerateBackupKeyIQSerializer alloc] initWithSchema:GENERATE_RESTORE_KEY_SCHEMA_ID schemaVersion:1];
    IQ_GET_ALL_BACKUPS_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:GET_ALL_BACKUPS_SCHEMA_ID schemaVersion:1];
    IQ_DELETE_BACKUPS_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:DELETE_BACKUPS_SCHEMA_ID schemaVersion:1];
    IQ_RESTORE_CHALLENGE_SERIALIZER = [[TLRestoreChallengeIQSerializer alloc] initWithSchema:RESTORE_CHALLENGE_SCHEMA_ID schemaVersion:1];
    IQ_RESTORE_REQUEST_SERIALIZER = [[TLRestoreRequestIQSerializer alloc] initWithSchema:RESTORE_REQUEST_SCHEMA_ID schemaVersion:1];
    
    IQ_ON_AUTH_CHALLENGE_SERIALIZER = [[TLOnAuthChallengeIQSerializer alloc] initWithSchema:ON_AUTH_CHALLENGE_SCHEMA_ID schemaVersion:2];
    IQ_ON_AUTH_REQUEST_SERIALIZER = [[TLOnAuthRequestIQSerializer alloc] initWithSchema:ON_AUTH_REQUEST_SCHEMA_ID schemaVersion:2];
    IQ_ON_AUTH_ERROR_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_AUTH_ERROR_SCHEMA_ID schemaVersion:1];
    IQ_ON_CREATE_ACCOUNT_SERIALIZER = [[TLOnCreateAccountIQSerializer alloc] initWithSchema:ON_CREATE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_ACCOUNT_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_DELETE_ACCOUNT_SCHEMA_ID schemaVersion:1];
    IQ_ON_SUBSCRIBE_FEATURE_SERIALIZER = [[TLOnSubscribeFeatureIQSerializer alloc] initWithSchema:ON_SUBSCRIBE_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_ON_CANCEL_FEATURE_SERIALIZER = [[TLOnSubscribeFeatureIQSerializer alloc] initWithSchema:ON_CANCEL_FEATURE_SCHEMA_ID schemaVersion:1];
    IQ_ON_SERVER_PING_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_SERVER_PING_SCHEMA_ID schemaVersion:1];
    IQ_ON_GENERATE_BACKUP_KEY_SERIALIZER = [[TLOnGenerateBackupKeyIQSerializer alloc] initWithSchema:ON_GENERATE_BACKUP_KEY_SCHEMA_ID schemaVersion:1];
    IQ_ON_GET_ALL_BACKUPS_SERIALIZER = [[TLOnGetAllBackupsIQSerializer alloc] initWithSchema:ON_GET_ALL_BACKUPS_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_BACKUPS_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_DELETE_BACKUPS_SCHEMA_ID schemaVersion:1];
    IQ_ON_TERMINATE_RESTORE_SERIALIZER = [[TLOnTerminateAccountRestoreIQSerializer alloc] initWithSchema:ON_TERMINATE_RESTORE_SCHEMA_ID schemaVersion:1];
    IQ_ON_RESTORE_CHALLENGE_SERIALIZER = [[TLOnAuthChallengeIQSerializer alloc] initWithSchema:ON_RESTORE_CHALLENGE_SCHEMA_ID schemaVersion:2];
    IQ_ON_RESTORE_CHALLENGE_ERROR_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_RESTORE_CHALLENGE_ERROR_SCHEMA_ID schemaVersion:1];
    IQ_ON_RESTORE_REQUEST_SERIALIZER = [[TLOnAuthRequestIQSerializer alloc] initWithSchema:ON_RESTORE_REQUEST_SCHEMA_ID schemaVersion:2];
    IQ_ON_RESTORE_REQUEST_ERROR_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_RESTORE_REQUEST_ERROR_SCHEMA_ID schemaVersion:1];

    AUTH_REQUEST_KINDS = [NSSet setWithObjects:
                          @(AUTH_CHALLENGE_REQUEST),
                          @(AUTH_REQUEST_REQUEST),
                          @(RESTORE_CHALLENGE_REQUEST),
                          @(RESTORE_REQUEST_REQUEST),
                          nil];
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
        [twinlife addPacketListener:IQ_ON_GENERATE_BACKUP_KEY_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onGenerateBackupKeyWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_GET_ALL_BACKUPS_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onGetAllBackupsWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_BACKUPS_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteBackupsWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_RESTORE_CHALLENGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onOnRestoreChallengeWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_RESTORE_REQUEST_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onOnRestoreRequestWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_RESTORE_CHALLENGE_ERROR_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onRestoreAuthErrorWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_RESTORE_REQUEST_ERROR_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onRestoreAuthErrorWithIQ:iq];
        }];

        [twinlife addPacketListener:IQ_ON_TERMINATE_RESTORE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onOnTerminateRestoreWithIQ:iq];
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
        securedConfiguration = self.activeSecuredConfiguration;
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
        switch (self.activeSecuredConfiguration.authenticationAuthority) {
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
    
    @synchronized (self.pendingRequests) {
        NSMutableArray<NSNumber *> *requestsToRemove = [NSMutableArray array];
        
        for (NSNumber *requestId in self.pendingRequests) {
            TLAccountPendingRequest *request = self.pendingRequests[requestId];
            
            if ([AUTH_REQUEST_KINDS containsObject:@(request.requestKind)]) {
                [requestsToRemove addObject:requestId];
            }
        }
        
        if (requestsToRemove.count > 0) {
            [self.pendingRequests removeObjectsForKeys:requestsToRemove];
        }
    }
    
    self.authUser = nil;
    
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

    TLAccountServiceSecuredConfiguration *accountSecuredConfiguration = self.activeSecuredConfiguration;
    
    if (![accountSecuredConfiguration isUpdatedWithEnvironmentId:environmentId] && ![accountSecuredConfiguration isUpdatedWithSubscribedFeatures:features]) {

        return;
    }

    // When the allowed features or the environment is defined, update the list.
    @synchronized (self) {
        if (environmentId) {
            accountSecuredConfiguration.environmentId = environmentId;
        }
        accountSecuredConfiguration.subscribedFeatures = features;
        [self.allowedFeatures removeAllObjects];
        if (features) {
            NSArray<NSString *> *featureList = [features componentsSeparatedByString: @","];
            [self.allowedFeatures addObjectsFromArray:featureList];
        }

        if (!self.twinlife.backupService.isRestoreInProgress) {
            // Save so that we can restore a default subscribedFeatures list when we don't have the network,
            // but only if we're not restoring a backup: we don't want to modify the config until
            // restore is successful and confirmed by the user.
            [self.securedConfiguration synchronize];
        }
    }
}

#pragma mark - TLAccountService

- (TLAccountServiceAuthenticationAuthority)getAuthenticationAuthority {
    DDLogVerbose(@"%@ getAuthenticationAuthority", LOG_TAG);
    
    if (!self.serviceOn) {
        return TLAccountServiceAuthenticationAuthorityDisabled;
    }
    
    return self.activeSecuredConfiguration.authenticationAuthority;
}

- (BOOL)isReconnectable {
    DDLogVerbose(@"%@ isReconnectable", LOG_TAG);
    
    if (!self.serviceOn) {
        return NO;
    }
    
    switch (self.activeSecuredConfiguration.authenticationAuthority) {
        case TLAccountServiceAuthenticationAuthorityDevice:
            return !self.activeSecuredConfiguration.isSignOut;

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
    
    if (!self.twinlife.backupService.isRestoreInProgress) {
        @synchronized(self) {
            self.securedConfiguration.authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            [self.securedConfiguration synchronize];
            self.authUser = nil;
        }
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
        TLAccountServiceSecuredConfiguration *securedConfiguration = self.activeSecuredConfiguration;
        username = [securedConfiguration deviceUsername];
        password = [securedConfiguration devicePassword];
        
        if ([securedConfiguration authenticationAuthority] != TLAccountServiceAuthenticationAuthorityUnregistered || !username || !password) {
            
            [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNotAuthorizedOperation errorParameter:nil];
            return;
        }
    }

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:username];
    NSString *twinlifeAccessToken = [[NSBundle mainBundle] bundleIdentifier];
    TLCreateAccountIQ *iq = [[TLCreateAccountIQ alloc] initWithSerializer:IQ_CREATE_ACCOUNT_SERIALIZER requestId:requestId applicationId:self.applicationId serviceId:self.serviceId apiKey:self.twinlife.twinlifeConfiguration.apiKey accessToken:twinlifeAccessToken applicationName:self.twinlife.twinlifeConfiguration.applicationName applicationVersion:self.twinlife.twinlifeConfiguration.applicationVersion twinlifeVersion:TWINLIFE_VERSION accountIdentifier:accountIdentifier accountPassword:password authToken:etoken];

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
    
    if (self.twinlife.backupService.isRestoreInProgress) {
        DDLogVerbose(@"%@ Restore in progress, ignoring delete account request", LOG_TAG);
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
    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(requestId)] = [[TLAccountPendingRequest alloc] initWithRequestKind:DELETE_ACCOUNT_REQUEST];
    }

    TLDeleteAccountIQ *iq = [[TLDeleteAccountIQ alloc] initWithSerializer:IQ_DELETE_ACCOUNT_SERIALIZER requestId:requestId accountIdentifier:accountIdentifier accountPassword:password];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)subscribeFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseProductId:(nonnull NSString *)purchaseProductId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {
    DDLogVerbose(@"%@ subscribeFeatureWithRequestId: %lld merchantId: %d purchaseProductId: %@ purchaseToken: %@ purchaseOrderId: %@", LOG_TAG, requestId, merchantId, purchaseProductId, purchaseToken, purchaseOrderId);
    
    if (!self.serviceOn) {
        return;
    }

    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(requestId)] = [[TLAccountPendingRequest alloc] initWithRequestKind:SUBSCRIBE_REQUEST];
    }

    TLSubscribeFeatureIQ *iq = [[TLSubscribeFeatureIQ alloc] initWithSerializer:IQ_SUBSCRIBE_FEATURE_SERIALIZER requestId:requestId merchantId:merchantId purchaseProductId:purchaseProductId purchaseToken:purchaseToken purchaseOrderId:purchaseOrderId];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)cancelFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {
    DDLogVerbose(@"%@ cancelFeatureWithRequestId: %lld merchantId: %d purchaseToken: %@ purchaseOrderId: %@", LOG_TAG, requestId, merchantId, purchaseToken, purchaseOrderId);
    
    if (!self.serviceOn) {
        return;
    }

    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(requestId)] = [[TLAccountPendingRequest alloc] initWithRequestKind:CANCEL_REQUEST];
    }

    TLCancelFeatureIQ *iq = [[TLCancelFeatureIQ alloc] initWithSerializer:IQ_CANCEL_FEATURE_SERIALIZER requestId:requestId merchantId:merchantId purchaseToken:purchaseToken purchaseOrderId:purchaseOrderId];

    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)restoreAccountSecuredConfigurationWithAccountConfiguration:(nonnull TLAccountServiceSecuredConfiguration *)accountConfiguration restoreCount:(int)restoreCount {
    DDLogVerbose(@"%@ restoreAccountSecuredConfigurationWithAccountConfiguration:%@ restoreCount:%d", LOG_TAG, accountConfiguration, restoreCount);
    
    accountConfiguration.incarnationCount = restoreCount;
    
    [accountConfiguration synchronize];
}

- (void)restoreChallengeWithAccountConfiguration:(nonnull TLAccountServiceSecuredConfiguration *)accountConfiguration backupId:(nonnull NSUUID *)backupId withBlock:(nonnull void (^)(TLBaseServiceErrorCode status))block {
    DDLogVerbose(@"%@ restoreChallengeWithAccountConfiguration: %@ backupId:%@ block:%@", LOG_TAG, accountConfiguration, backupId.UUIDString, block);
    
    NSString *username = accountConfiguration.deviceUsername;
    
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

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:username];
    
    TLRestoreChallengeIQ *restoreChallengeIQ = [[TLRestoreChallengeIQ alloc] initWithSerializer:IQ_RESTORE_CHALLENGE_SERIALIZER requestId:[TLTwinlife newRequestId] backupId:backupId accountIdentifier:accountIdentifier nonce:deviceNonce];
    
    [self sendBinaryIQ:restoreChallengeIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    
    TLRestoreChallengePendingRequest *pendingRequest = [[TLRestoreChallengePendingRequest alloc] initWithAccountSecuredConfiguration:accountConfiguration restoreChallengeIQ:restoreChallengeIQ consumer:^(TLBaseServiceErrorCode errorCode, id _Nullable result) {
            block(errorCode);
    }];
    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(restoreChallengeIQ.requestId)] = pendingRequest;
    }
}

- (void) onOnRestoreChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnRestoreChallengeWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLOnAuthChallengeIQ.class]) {
        return;
    }
    
    TLOnAuthChallengeIQ *onRestoreChallengeIQ = (TLOnAuthChallengeIQ *)iq;
    
    [self receivedBinaryIQ:iq];
    
    TLRestoreChallengePendingRequest *restoreChallenge = (TLRestoreChallengePendingRequest *) [self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLRestoreChallengePendingRequest.class];
    if (!restoreChallenge) {
        return;
    }
    
    TLRestoreChallengeIQ *restoreChallengeIQ = restoreChallenge.restoreChallengeIQ;
    
    if (restoreChallengeIQ.requestId != onRestoreChallengeIQ.requestId) {
        DDLogWarn(@"%@ onOnRestoreChallenge: couldn't find request. requestId=%lld, TLRestoreChallengeIQ=%@", LOG_TAG, onRestoreChallengeIQ.requestId, restoreChallengeIQ);
        self.authUser = nil;
        
        restoreChallenge.consumer(TLBaseServiceErrorCodeLibraryError, nil);
        
        return;
    }
    
    NSString *resource = self.twinlife.resource;
    int64_t requestId = [TLTwinlife newRequestId];
    
    NSString *password = restoreChallenge.accountSecuredConfiguration.devicePassword;
    
    if (!password) {
        DDLogError(@"%@ No restoreAccountPassword", LOG_TAG);
        
        self.authUser = nil;
        
        restoreChallenge.consumer(TLBaseServiceErrorCodeLibraryError, nil);
        
        return;
    }
    
    // Truncate the password because old devices registered with a password > 32 chars but it was truncated by the server.
    // If we continue using that full password, the authentication will fail!
    if (password.length > MAX_PASSWORD_LENGTH) {
        NSRange passwordMaxRange = {0, MAX_PASSWORD_LENGTH};
        password = [password substringWithRange:passwordMaxRange];
    }

    // Build the auth message that must be signed.
    NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [restoreChallengeIQ clientFirstMessageBare], [onRestoreChallengeIQ serverFirstMessageBare], resource];

    // Compute everything according to RFC 5802 section 3. SCRAM Algorithm Overview
    NSData *saltedPasswordData = [TLAccountService createSaltedPasswordWithAlgorithm:kCCHmacAlgSHA1 password:password salt:onRestoreChallengeIQ.salt iterations:onRestoreChallengeIQ.iterations];
    
    NSData *clientKeyData = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Client Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    unsigned char result[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1([clientKeyData bytes], (CC_LONG)[clientKeyData length], result);
    NSData *storedKeyData = [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];

    NSData *clientSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:storedKeyData];

    // Compute the server key for last step server signature verification.
    NSData *serverKey = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Server Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    // Create the client proof to send.
    NSData *clientProof = [TLAccountService xorData:clientKeyData withData:clientSignature];

    TLRestoreRequestIQ *restoreRequestIQ = [[TLRestoreRequestIQ alloc] initWithSerializer:IQ_RESTORE_REQUEST_SERIALIZER requestId:requestId accountIdentifier:restoreChallengeIQ.accountIdentifier resourceIdentifier:resource deviceNonce:restoreChallengeIQ.nonce deviceProof:clientProof backupId:restoreChallengeIQ.backupId];
    
    [self sendBinaryIQ:restoreRequestIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    
    TLRestoreRequestPendingRequest *pendingRequest = [[TLRestoreRequestPendingRequest alloc] initWithRestoreChallengePendingRequest:restoreChallenge onRestoreChallengeIQ:onRestoreChallengeIQ serverKey:serverKey];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(requestId)] = pendingRequest;
    }
}

- (void) onOnRestoreRequestWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnRestoreRequestWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:TLOnAuthRequestIQ.class]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    TLRestoreRequestPendingRequest *restoreRequest = (TLRestoreRequestPendingRequest *)[self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLRestoreRequestPendingRequest.class];
    if (!restoreRequest){
        return;
    }
    
    TLOnAuthRequestIQ *onAuthRequestIQ = (TLOnAuthRequestIQ *)iq;
    
    TLRestoreChallengeIQ *restoreChallengeIQ = restoreRequest.restoreChallengeIQ;
    TLOnAuthChallengeIQ *onRestoreChallengeIQ = restoreRequest.onRestoreChallengeIQ;
    NSData *serverKey = restoreRequest.serverKey;
    
    NSData *serverSignature = nil;

    // Build the auth message that must be signed.
    NSString *resource = self.twinlife.resource;
    NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [restoreChallengeIQ clientFirstMessageBare], [onRestoreChallengeIQ serverFirstMessageBare], resource];

    serverSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:serverKey];

    // Verify the server signature.
    if (!serverSignature || ![serverSignature isEqualToData:onAuthRequestIQ.serverSignature]) {
        restoreRequest.consumer(TLBaseServiceErrorCodeServerError, nil);
        return;
    }
    
    self.restoreSecuredConfiguration = restoreRequest.accountSecuredConfiguration;
    
    self.authUser = [self.twinlife toBareJIDWithUsername:restoreChallengeIQ.accountIdentifier];
    [self.twinlife onSignIn];
    
    restoreRequest.consumer(TLBaseServiceErrorCodeSuccess, nil);
}

- (void)onRestoreAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onRestoreAuthErrorWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:TLBinaryErrorPacketIQ.class]) {
        return;
    }
    
    TLBinaryErrorPacketIQ *errorPacketIQ = (TLBinaryErrorPacketIQ *)iq;
    
    DDLogError(@"%@ Restore auth failed: %@", LOG_TAG, errorPacketIQ);
    
    self.authUser = nil;

    NSNumber *requestId = [NSNumber numberWithLongLong:iq.requestId];
        
    TLConsumerAccountPendingRequest *pendingRequest = (TLConsumerAccountPendingRequest *)[self removePendingRequestWithRequestId:requestId expectedClass:TLRestoreChallengePendingRequest.class];
    
    if (!pendingRequest){
        pendingRequest = (TLConsumerAccountPendingRequest *)[self removePendingRequestWithRequestId:requestId expectedClass:TLRestoreRequestPendingRequest.class];
    }
    
    if (pendingRequest) {
        pendingRequest.consumer(errorPacketIQ.errorCode, nil);
    }
}

- (BOOL)isCurrentAccountWithAccountConfiguration:(nonnull TLAccountServiceSecuredConfiguration *)accountConfiguration {

    return [self.securedConfiguration.deviceUsername isEqualToString:accountConfiguration.deviceUsername] && [self.securedConfiguration.devicePassword isEqualToString:accountConfiguration.devicePassword];
}

- (void)commitRestoreWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status, int incarnationCount))block {
    DDLogVerbose(@"%@ commitRestoreWithBlock: %@", LOG_TAG, block);
    
    NSNumber *requestId = [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
    
    TLTerminateAccountRestoreIQ *iq = [[TLTerminateAccountRestoreIQ alloc] initWithSerializer:IQ_TERMINATE_ACCOUNT_RESTORE_SERIALIZER requestId:requestId.longLongValue commit:YES];
    
    TLTerminateRestorePendingRequest *pendingRequest = [[TLTerminateRestorePendingRequest alloc] initWithConsumer:^(TLBaseServiceErrorCode errorCode, id  _Nullable result) {
        
        if (![result isKindOfClass:NSNumber.class]) {
            DDLogError(@"%@ Expected incarnationCount (int) but got: %@", LOG_TAG, result);
            block(TLBaseServiceErrorCodeLibraryError, -1);
            return;
        }
        
        block(errorCode, ((NSNumber *)result).intValue);
    }];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[requestId] = pendingRequest;
    }
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)rollbackRestoreWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status, int incarnationCount))block {
    DDLogVerbose(@"%@ rollbackRestoreWithBlock: %@", LOG_TAG, block);

    NSNumber *requestId = [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
    
    TLTerminateAccountRestoreIQ *iq = [[TLTerminateAccountRestoreIQ alloc] initWithSerializer:IQ_TERMINATE_ACCOUNT_RESTORE_SERIALIZER requestId:requestId.longLongValue commit:NO];
    
    TLTerminateRestorePendingRequest *pendingRequest = [[TLTerminateRestorePendingRequest alloc] initWithConsumer:^(TLBaseServiceErrorCode errorCode, id  _Nullable result) {
        // rollback: we don't care about the incarnationCount
        block(errorCode, -1);
    }];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[requestId] = pendingRequest;
    }
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void) onOnTerminateRestoreWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnTerminateRestoreWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:TLOnTerminateAccountRestoreIQ.class]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    TLTerminateRestorePendingRequest *terminateRequest = (TLTerminateRestorePendingRequest *) [self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLTerminateRestorePendingRequest.class];
    if (!terminateRequest) {
        return;
    }
    
    TLOnTerminateAccountRestoreIQ *onTerminateAccountRestoreIQ = (TLOnTerminateAccountRestoreIQ *)iq;
    
    terminateRequest.consumer(onTerminateAccountRestoreIQ.errorCode, @(onTerminateAccountRestoreIQ.restoreCount));
}


- (nullable NSUUID *)environmentId {
    DDLogVerbose(@"%@ environmentId", LOG_TAG);

    return self.activeSecuredConfiguration.environmentId;
}

- (void)generateBackupKeyWithBackupId:(nonnull NSUUID *)backupId password:(nonnull NSData *)password salt:(nonnull NSData *)salt forRestore:(BOOL)forRestore withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, NSData * _Nullable serverDerivedKey, NSUUID * _Nullable lastBackupId, int64_t lastBackupTimestamp))block {
    DDLogVerbose(@"%@ generateBackupKeyWithBackupId:%@", LOG_TAG, backupId.UUIDString);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLCryptoService *cryptoService = self.twinlife.cryptoService;

    NSData *derivedKey = [cryptoService deriveKeyWithPassword:password salt:salt];
        
    NSNumber *requestId = [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
    
    TLGenerateBackupPasswordPendingRequest *pendingRequest = [[TLGenerateBackupPasswordPendingRequest alloc] initWithConsumer:^(TLBaseServiceErrorCode errorCode, TLOnGenerateBackupKeyIQ *_Nullable result) {
        if (errorCode != TLBaseServiceErrorCodeSuccess) {
            block(errorCode, nil, nil, -1);
            return;
        }
        
        if (!result || ![result isKindOfClass:TLOnGenerateBackupKeyIQ.class]) {
            DDLogError(@"%@ Expected iq (TLOnGenerateBackupKeyIQ *) but got: %@", LOG_TAG, result);
            block(TLBaseServiceErrorCodeLibraryError, nil, nil, -1);
            return;
        }
        
        TLOnGenerateBackupKeyIQ *iq = (TLOnGenerateBackupKeyIQ *)result;
        
        NSData *finalKey = [cryptoService deriveKeyWithPassword:iq.derivedServerKey salt:salt];
        
        block(TLBaseServiceErrorCodeSuccess, finalKey, iq.lastBackupId, iq.lastBackupTimestamp);
    }];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[requestId] = pendingRequest;
    }
    
    TLBinaryPacketIQSerializer *serializer = forRestore ? IQ_GENERATE_RESTORE_KEY_SERIALIZER : IQ_GENERATE_BACKUP_KEY_SERIALIZER;
    
    TLGenerateBackupKeyIQ *iq = [[TLGenerateBackupKeyIQ alloc] initWithSerializer:serializer requestId:requestId.longLongValue backupId:backupId derivedUserKey:derivedKey];
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)onGenerateBackupKeyWithIQ:(TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGenerateBackupKeyWithIQ:%@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnGenerateBackupKeyIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
         
    TLGenerateBackupPasswordPendingRequest *pendingRequest = (TLGenerateBackupPasswordPendingRequest *)[self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLGenerateBackupPasswordPendingRequest.class];
    if (!pendingRequest){
        return;
    }
    
    TLOnGenerateBackupKeyIQ *onGenerateBackupKeyIQ = (TLOnGenerateBackupKeyIQ *)iq;
    pendingRequest.consumer(TLBaseServiceErrorCodeSuccess, onGenerateBackupKeyIQ);
}


- (void)removeRestoreAccountConfiguration {
    DDLogVerbose(@"%@ removeRestoreAccountConfiguration", LOG_TAG);
    self.restoreSecuredConfiguration = nil;
}

- (nullable TLAccountServiceSecuredConfiguration *)activeSecuredConfiguration {
    return self.restoreSecuredConfiguration ? self.restoreSecuredConfiguration : self.securedConfiguration;
}


- (void)getAllBackupsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status, NSArray<TLBackupInfo *> * _Nullable backups))block {
    DDLogVerbose(@"%@ getAllBackupsWithBlock", LOG_TAG);
    
    if (!self.serviceOn) {
        return;
    }
    
    NSNumber *requestId = [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
    
    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_GET_ALL_BACKUPS_SERIALIZER requestId:requestId.longLongValue];
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    
    TLGetAllBackupsPendingRequest *pendingRequest = [[TLGetAllBackupsPendingRequest alloc] initWithConsumer:^(TLBaseServiceErrorCode errorCode, id  _Nullable result) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || ![result isKindOfClass:NSArray.class]) {
            block(errorCode, [NSArray array]);
        } else {
            block(TLBaseServiceErrorCodeSuccess, result);
        }
    }];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[requestId] = pendingRequest;
    }
}

- (void)onGetAllBackupsWithIQ:(TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetAllBackupsWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnGetAllBackupsIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnGetAllBackupsIQ *onGetAllBackupsIQ = (TLOnGetAllBackupsIQ *)iq;
    
        
    TLGetAllBackupsPendingRequest *pendingRequest = (TLGetAllBackupsPendingRequest *)[self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLGetAllBackupsPendingRequest.class];
    if (!pendingRequest){
        return;
    }
        
    pendingRequest.consumer(TLBaseServiceErrorCodeSuccess, onGetAllBackupsIQ.backups);
}

- (void)deleteBackupsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status))block {
    DDLogVerbose(@"%@ deleteBackupsWithBlock", LOG_TAG);

    if (!self.serviceOn) {
        return;
    }
    
    NSNumber *requestId = [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
        
    TLBinaryPacketIQ *iq = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_DELETE_BACKUPS_SERIALIZER requestId:requestId.longLongValue];
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    
    TLDeleteBackupsPendingRequest *pendingRequest = [[TLDeleteBackupsPendingRequest alloc] initWithConsumer:^(TLBaseServiceErrorCode errorCode, id  _Nullable result) {
        block(errorCode);
    }];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[requestId] = pendingRequest;
    }

}

- (void)onDeleteBackupsWithIQ:(TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteBackupsWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLBinaryErrorPacketIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLBinaryErrorPacketIQ *onDeleteBackupIQ = (TLBinaryErrorPacketIQ *)iq;
    
    TLDeleteBackupsPendingRequest *pendingRequest = (TLDeleteBackupsPendingRequest *)[self removePendingRequestWithRequestId:@(onDeleteBackupIQ.requestId) expectedClass:TLDeleteBackupsPendingRequest.class];
    
    if (pendingRequest) {
        pendingRequest.consumer(onDeleteBackupIQ.errorCode, nil);
    }
}

#pragma mark - TLAccountService IQ

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);

    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];

    [self receivedBinaryIQ:errorPacketIQ];

    TLAccountPendingRequest *pendingRequest = [self removePendingRequestWithRequestId:lRequestId expectedClass:TLAccountPendingRequest.class];
    
    // If we have a pending request, this is a subscribe, cancel or delete account and we report the error.
    if (pendingRequest != nil) {
        if (pendingRequest.requestKind == DELETE_ACCOUNT_REQUEST) {
            [self onErrorWithRequestId:requestId errorCode:errorCode errorParameter:nil];
        } else if ([pendingRequest isKindOfClass:TLConsumerAccountPendingRequest.class]){
            ((TLConsumerAccountPendingRequest *)pendingRequest).consumer(errorCode, nil);
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
    
    //TODO: Android implementation calls onSignInError(), do the same here?
}

- (void)onAuthChallengeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAuthChallengeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnAuthChallengeIQ class]]) {
        return;
    }

    uint64_t receiveTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    [self receivedBinaryIQ:iq];

    TLAuthChallengePendingRequest *challengeRequest = (TLAuthChallengePendingRequest *)[self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLAuthChallengePendingRequest.class];
    if (!challengeRequest) {
        return;
    }
    
    // Verify that this is our challenge request.
    if (challengeRequest.authChallengeIQ.requestId != iq.requestId) {

        self.authUser = nil;
        [self.serverStream disconnect];
        return;
    }

    // Make sure we have the password, if not abort this authentication.
    NSString *password = self.activeSecuredConfiguration.devicePassword;
    if (!password) {

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

    TLOnAuthChallengeIQ *onAuthChallengeIQ = (TLOnAuthChallengeIQ *)iq;

    // Build the auth message that must be signed.
    NSString *resource = self.twinlife.resource;
    NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [challengeRequest.authChallengeIQ clientFirstMessageBare], [onAuthChallengeIQ serverFirstMessageBare], resource];

    // Compute everything according to RFC 5802 section 3. SCRAM Algorithm Overview
    NSData *saltedPasswordData = [TLAccountService createSaltedPasswordWithAlgorithm:kCCHmacAlgSHA1 password:password salt:onAuthChallengeIQ.salt iterations:onAuthChallengeIQ.iterations];
    
    NSData *clientKeyData = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Client Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    unsigned char result[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1([clientKeyData bytes], (CC_LONG)[clientKeyData length], result);
    NSData *storedKeyData = [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];

    NSData *clientSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:storedKeyData];

    // Compute the server key for last step server signature verification.
    NSData *serverKey = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[@"Server Key" dataUsingEncoding:NSUTF8StringEncoding] key:saltedPasswordData];

    // Create the client proof to send.
    NSData *clientProof = [TLAccountService xorData:clientKeyData withData:clientSignature];

    int64_t deviceTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    uint64_t sendTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

    int deviceState = 0;
    int deviceLatency = (int) ((sendTime - receiveTime) / 1000000L);

    TLAuthRequestIQ *authRequestIQ = [[TLAuthRequestIQ alloc] initWithSerializer:IQ_AUTH_REQUEST_SERIALIZER requestId:[TLTwinlife newRequestId] accountIdentifier:challengeRequest.authChallengeIQ.accountIdentifier resourceIdentifier:resource deviceNonce:challengeRequest.authChallengeIQ.nonce deviceProof:clientProof deviceState:deviceState deviceLatency:deviceLatency deviceTimestamp:deviceTimestamp serverTimestamp:onAuthChallengeIQ.serverTimestamp incarnationCount:self.securedConfiguration.incarnationCount];

    // Serialize with the default binary encoder.
    NSData *data = [authRequestIQ serializeWithSerializerFactory:self.serializerFactory];

    if (![self sendBinaryWithRequestId:authRequestIQ.requestId data:data timeout:DEFAULT_REQUEST_TIMEOUT]) {
        [self.serverStream disconnect];
        return;
    }
    
    TLAuthRequestPendingRequest *pendingRequest = [[TLAuthRequestPendingRequest alloc] initWithAuthChallengeIQ:challengeRequest.authChallengeIQ onAuthChallengeIQ:onAuthChallengeIQ serverKey:serverKey authRequestTime:sendTime];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(authRequestIQ.requestId)] = pendingRequest;
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

    TLAuthRequestPendingRequest *pendingRequest = (TLAuthRequestPendingRequest *)[self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLAuthRequestPendingRequest.class];
    if (!pendingRequest) {
        return;
    }
    
    TLOnAuthRequestIQ *onAuthRequestIQ = (TLOnAuthRequestIQ *)iq;
    NSData *serverSignature = nil;

    // Build the auth message that must be signed.
    NSString *resource = self.twinlife.resource;
        NSString *authMessage = [[NSString alloc] initWithFormat:@"%@,%@,%@", [pendingRequest.authChallengeIQ clientFirstMessageBare], [pendingRequest.onAuthChallengeIQ serverFirstMessageBare], resource];

        serverSignature = [TLAccountService createHmacWithAlgorithm:kCCHmacAlgSHA1 data:[authMessage dataUsingEncoding:NSUTF8StringEncoding] key:pendingRequest.serverKey];
    
    NSString *authUser = pendingRequest.authChallengeIQ.accountIdentifier;

    // Verify the server signature.
    if (!serverSignature || ![serverSignature isEqualToData:onAuthRequestIQ.serverSignature]) {

        [self.serverStream disconnect];
        return;
    }

    self.authUser = authUser;
    [self.twinlife adjustTimeWithServerTime:onAuthRequestIQ.serverTimestamp deviceTime:deviceTimestamp serverLatency:onAuthRequestIQ.serverLatency requestTime:(receiveTime - pendingRequest.authRequestTime) / 1000000L];
    [self.twinlife onSignIn];
}

- (void)onAuthErrorWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAuthErrorWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLBinaryErrorPacketIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLBinaryErrorPacketIQ *errorPacketIQ = (TLBinaryErrorPacketIQ *)iq;

    [self removePendingRequestWithRequestId:@(iq.requestId) expectedClass:TLAccountPendingRequest.class];
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

        // User account has been deleted or restored on another device: user must uninstall.
        case TLBaseServiceErrorCodeItemNotFound:
        case TLBaseServiceErrorCodeAccountRestored:
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
    
    TLAccountPendingRequest *pendingRequest = [self removePendingRequestWithRequestId:lRequestId expectedClass:TLAccountPendingRequest.class];
    
    if (!pendingRequest) {
        return;
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

    if (self.twinlife.backupService.isRestoreInProgress) {
        DDLogVerbose(@"%@ Restore in progress, abort signin", LOG_TAG);
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

    NSString *accountIdentifier = [self.twinlife toBareJIDWithUsername:self.activeSecuredConfiguration.deviceUsername];
    NSString *twinlifeAccessToken = [[NSBundle mainBundle] bundleIdentifier];
    TLAuthChallengeIQ *authChallengeIQ = [[TLAuthChallengeIQ alloc] initWithSerializer:IQ_AUTH_CHALLENGE_SERIALIZER requestId:[TLTwinlife newRequestId] applicationId:self.applicationId serviceId:self.serviceId apiKey:self.twinlife.twinlifeConfiguration.apiKey accessToken:twinlifeAccessToken applicationName:self.twinlife.twinlifeConfiguration.applicationName applicationVersion:self.twinlife.twinlifeConfiguration.applicationVersion twinlifeVersion:[TLTwinlife VERSION] accountIdentifier:accountIdentifier nonce:deviceNonce];

    // And send as a raw IQ.
    NSData *data = [authChallengeIQ serializeWithSerializerFactory:self.serializerFactory];

    if (![self sendBinaryWithRequestId:authChallengeIQ.requestId data:data timeout:DEFAULT_REQUEST_TIMEOUT]) {

        return;
    }
    
    TLAuthChallengePendingRequest *pendingRequest = [[TLAuthChallengePendingRequest alloc] initWithAuthChallengeIQ:authChallengeIQ];
    
    @synchronized (self.pendingRequests) {
        self.pendingRequests[@(authChallengeIQ.requestId)] = pendingRequest;
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

- (nullable TLAccountPendingRequest *)removePendingRequestWithRequestId:(nonnull NSNumber *)requestId expectedClass:(Class)expectedClass {
    TLAccountPendingRequest *pendingRequest = nil;
    
    @synchronized (self.pendingRequests) {
        pendingRequest = self.pendingRequests[requestId];
        if (pendingRequest) {
            [self.pendingRequests removeObjectForKey:requestId];
        }
    }
    
    if (!pendingRequest) {
        return nil;
    }
    
    if (![pendingRequest isKindOfClass:expectedClass]) {
        DDLogError(@"%@ Invalid request type for requestId=%@. Expected:%@, actual:%@", LOG_TAG, requestId, expectedClass, pendingRequest.class);
        return nil;
    }
    
    return pendingRequest;
}

@end
