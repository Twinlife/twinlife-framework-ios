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

#include <mach/mach_time.h>

#import <CocoaLumberjack.h>

#import "TLBaseService.h"
#import "TLBaseServiceImpl.h"
#import "TLTwinlife.h"
#import "TLDataInputStream.h"
#import "TLAttributeNameValue.h"
#import "TLJobService.h"
#import "TLBinaryPacketIQ.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLAssertion.h"

#import <sqlite3.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int8_t ATTRIBUTE_NAME_BITMAP_VALUE = 0;
static const int8_t ATTRIBUTE_NAME_BOOLEAN_VALUE = 1;
static const int8_t ATTRIBUTE_NAME_LONG_VALUE = 2;
static const int8_t ATTRIBUTE_NAME_STRING_VALUE = 3;
static const int8_t ATTRIBUTE_NAME_VOID_VALUE = 4;
static const int8_t ATTRIBUTE_NAME_UUID_VALUE = 5;

#define DATABASE_ERROR_DELAY_GUARD (2*120*1000) // 2 minutes

//
// Implementation: TLRequestInfo
//

@implementation TLRequestInfo

- (nonnull instancetype)initWithRequestId:(int64_t)requestId isBinary:(BOOL)isBinary {
 
    _requestId = requestId;
    _isBinary = isBinary;
    return self;
}

- (BOOL)isEqual:(id)object {

    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[TLRequestInfo class]]) {
        return NO;
    }

    TLRequestInfo *item = (TLRequestInfo *)object;

    return self.requestId == item.requestId;
}

- (NSUInteger)hash {

    return (NSUInteger)(self.requestId ^ (self.requestId >> 32));
}

@end

//
// TLServiceStats
//

#undef LOG_TAG
#define LOG_TAG @"TLServiceStats"

@implementation TLServiceStats

- (nonnull instancetype)initWithCount:(int)sendCount errorCount:(int)errorCount disconnectedCount:(int)disconnectedCount timeoutCount:(int)timeoutCount {
    
    self = [super init];
    
    _sendPacketCount = sendCount;
    _sendErrorCount = errorCount;
    _sendDisconnectedCount = disconnectedCount;
    _sendTimeoutCount = timeoutCount;
    return self;
}

@end

//
// Interface: TLTurnServer
//
#undef LOG_TAG
#define LOG_TAG @"TLTurnServer"

@implementation TLTurnServer

- (nonnull instancetype)initWithUrl:(nonnull NSString *)url username:(nonnull NSString *)username password:(nonnull NSString *)password {
    DDLogVerbose(@"%@ initWithUrl: %@ username: %@ password: %@", LOG_TAG, url, username, password);
    
    self = [super init];
    
    _url = url;
    _username = username;
    _password = password;
    return self;
}

@end

//
// TLBaseServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLBaseServiceConfiguration"

@implementation TLBaseServiceConfiguration

- (nonnull instancetype)initWithBaseServiceId:(TLBaseServiceId)baseServiceId version:(nonnull NSString *)version serviceOn:(BOOL)serviceOn {
    DDLogVerbose(@"%@ initWithBaseServiceId: %d version: %@ serviceOn: %@", LOG_TAG, baseServiceId, version, serviceOn ? @"YES" : @"NO");
    
    self = [super init];
    
    _baseServiceId = baseServiceId;
    _version = version;
    _serviceOn = serviceOn;
    return self;
}

@end

//
// TLBaseServiceImplConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLBaseServiceImplConfiguration"

@implementation TLBaseServiceImplConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super init];
    
    _maxSentFrameSize = TL_BASE_SERVICE_IMPL_MAX_FRAME_SIZE;
    _maxSentFrameRate = TL_BASE_SERVICE_IMPL_MAX_FRAME_RATE;
    _maxReceivedFrameSize = TL_BASE_SERVICE_IMPL_MAX_FRAME_SIZE;
    _maxReceivedFrameRate = TL_BASE_SERVICE_IMPL_MAX_FRAME_RATE;
    _turnServers = [[NSMutableArray alloc] initWithCapacity:4];
    _hostnames = [[NSArray alloc] init];
    _environmentId = nil;
    return self;
}

- (BOOL)isUpdatedConfiguration:(nonnull TLBaseServiceImplConfiguration *)configuration {
    DDLogVerbose(@"%@ isUpdatedConfiguration: %@", LOG_TAG, configuration);
    
    if (self.maxSentFrameSize != configuration.maxSentFrameSize) {
        return YES;
    }
    if (self.maxSentFrameRate != configuration.maxSentFrameRate) {
        return YES;
    }
    if (self.maxReceivedFrameRate != configuration.maxReceivedFrameRate) {
        return YES;
    }
    if (self.maxReceivedFrameSize != configuration.maxReceivedFrameSize) {
        return YES;
    }
    
    // Don't compare the turnServer configuration: we don't save them.
    return NO;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLBaseServiceImplConfiguration\n"];
    [string appendFormat:@" maxSentFrameSize=%d\n", self.maxSentFrameSize];
    [string appendFormat:@" maxSentFrameRate=%d\n", self.maxSentFrameRate];
    [string appendFormat:@" maxReceivedFrameSize=%d\n", self.maxReceivedFrameSize];
    [string appendFormat:@" maxReceivedFrameRate=%d\n", self.maxReceivedFrameRate];
    return string;
}

@end

//
// TLBaseService
//

#undef LOG_TAG
#define LOG_TAG @"TLBaseService"

@implementation TLBaseService

+ (int64_t)UNDEFINED_REQUEST_ID {
    
    return -1L;
}

+ (int64_t)DEFAULT_REQUEST_ID {
    
    return 0;
}

+ (nullable TLAttributeNameValue *)deserializeWithDataInputStream:(nonnull TLDataInputStream *)dataInputStream {
    DDLogVerbose(@"%@ deserialize: %@", LOG_TAG, dataInputStream);
    
    int8_t type = [dataInputStream readInt8];
    
    NSString *name;
    switch (type) {
        case ATTRIBUTE_NAME_BITMAP_VALUE: {
            // Extract but drop and ignore this old attribute which is not supported.
            [dataInputStream readString];
            [dataInputStream readData];
            return nil;
        }
            
        case ATTRIBUTE_NAME_BOOLEAN_VALUE: {
            name = [dataInputStream readString];
            BOOL booleanValue = [dataInputStream readBoolean];
            return [[TLAttributeNameBooleanValue alloc] initWithName:name boolValue:booleanValue];
        }
            
        case ATTRIBUTE_NAME_LONG_VALUE: {
            name = [dataInputStream readString];
            int64_t longValue = [dataInputStream readInt64];
            return [[TLAttributeNameLongValue alloc] initWithName:name longValue:longValue];
        }
            
        case ATTRIBUTE_NAME_STRING_VALUE: {
            name = [dataInputStream readString];
            NSString *stringValue = [dataInputStream readString];
            return [[TLAttributeNameStringValue alloc] initWithName:name stringValue:stringValue];
        }
            
        case ATTRIBUTE_NAME_VOID_VALUE: {
            name = [dataInputStream readString];
            return [[TLAttributeNameVoidValue alloc] initWithName:name];
        }
            
        case ATTRIBUTE_NAME_UUID_VALUE: {
            name = [dataInputStream readString];
            NSUUID *uuidValue = [dataInputStream readUUID];
            return [[TLAttributeNameUUIDValue alloc] initWithName:name uuidValue:uuidValue];
        }
            
        default:
            return nil;
    }
}

+ (nonnull NSNumber *)newRequestId {
    
    return [NSNumber numberWithLongLong:[TLTwinlife newRequestId]];
}

+ (int)fromErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fromErrorCode: %d", LOG_TAG, errorCode);

    switch (errorCode) {
        case TLBaseServiceErrorCodeSuccess:
            return 0;
            
        case TLBaseServiceErrorCodeBadRequest:
            return 1;
            
        case TLBaseServiceErrorCodeCanceledOperation:
            return 2;
            
        case TLBaseServiceErrorCodeFeatureNotImplemented:
            return 3;
            
        case TLBaseServiceErrorCodeFeatureNotSupportedByPeer:
            return 4;
            
        case TLBaseServiceErrorCodeServerError:
            return 5;
            
        case TLBaseServiceErrorCodeItemNotFound:
            return 6;
            
        case TLBaseServiceErrorCodeLibraryError:
            return 7;
            
        case TLBaseServiceErrorCodeLibraryTooOld:
            return 8;
            
        case TLBaseServiceErrorCodeNotAuthorizedOperation:
            return 9;
            
        case TLBaseServiceErrorCodeServiceUnavailable:
            return 10;
            
        case TLBaseServiceErrorCodeTwinlifeOffline:
            return 11;
            
        case TLBaseServiceErrorCodeWebrtcError:
            return 12;
            
        case TLBaseServiceErrorCodeWrongLibraryConfiguration:
            return 13;
            
        case TLBaseServiceErrorCodeNoStorageSpace:
            return 14;
            
        case TLBaseServiceErrorCodeNoPermission:
            return 15;
            
        case TLBaseServiceErrorCodeLimitReached:
            return 16;
            
        case TLBaseServiceErrorCodeDatabaseError:
            return 17;

        case TLBaseServiceErrorCodeQueued:
            return 18;

        case TLBaseServiceErrorCodeQueuedNoWakeup:
            return 19;

        case TLBaseServiceErrorCodeExpired:
            return 20;

        case TLBaseServiceErrorCodeInvalidPublicKey:
            return 21;

        case TLBaseServiceErrorCodeInvalidPrivateKey:
            return 22;

        case TLBaseServiceErrorCodeNoPublicKey:
            return 23;

        case TLBaseServiceErrorCodeNoPrivateKey:
            return 24;

        case TLBaseServiceErrorCodeBadSignature:
            return 25;

        case TLBaseServiceErrorCodeBadSignatureFormat:
            return 26;

        case TLBaseServiceErrorCodeBadSignatureMissingAttribute:
            return 27;

        case TLBaseServiceErrorCodeBadSignatureNotSignedAttribute:
            return 28;

        case TLBaseServiceErrorCodeEncryptError:
            return 29;

        case TLBaseServiceErrorCodeDecryptError:
            return 30;

        case TLBaseServiceErrorCodeBadEncryptionFormat:
            return 31;

        case TLBaseServiceErrorCodeNoSecretKey:
            return 32;

        case TLBaseServiceErrorCodeNotEncrypted:
            return 33;

        case TLBaseServiceErrorCodeFileNotFound:
            return 34;

        case TLBaseServiceErrorCodeFileNotSupported:
            return 35;

        case TLBaseServiceErrorCodeTimeoutError:
        case TLBaseServiceErrorCodeAccountDeleted:
        case TLBaseServiceErrorCodeDatabaseKeyError:
            break;
    }
    return 7;
}

+ (TLBaseServiceErrorCode)toErrorCode:(int)errorCode {
    DDLogVerbose(@"%@ toErrorCode: %d", LOG_TAG, errorCode);

    switch (errorCode) {
        case 0:
            errorCode = TLBaseServiceErrorCodeSuccess;
            break;
            
        case 1:
            errorCode = TLBaseServiceErrorCodeBadRequest;
            break;
            
        case 2:
            errorCode = TLBaseServiceErrorCodeCanceledOperation;
            break;
            
        case 3:
            errorCode = TLBaseServiceErrorCodeFeatureNotImplemented;
            break;
            
        case 4:
            errorCode = TLBaseServiceErrorCodeFeatureNotSupportedByPeer;
            break;
            
        case 5:
            errorCode = TLBaseServiceErrorCodeServerError;
            break;
            
        case 6:
            errorCode = TLBaseServiceErrorCodeItemNotFound;
            break;
            
        case 7:
            errorCode = TLBaseServiceErrorCodeLibraryError;
            break;
            
        case 8:
            errorCode = TLBaseServiceErrorCodeLibraryTooOld;
            break;
            
        case 9:
            errorCode = TLBaseServiceErrorCodeNotAuthorizedOperation;
            break;
            
        case 10:
            errorCode = TLBaseServiceErrorCodeServiceUnavailable;
            break;
            
        case 11:
            errorCode = TLBaseServiceErrorCodeTwinlifeOffline;
            break;
            
        case 12:
            errorCode = TLBaseServiceErrorCodeWebrtcError;
            break;
            
        case 13:
            errorCode = TLBaseServiceErrorCodeWrongLibraryConfiguration;
            break;
            
        case 14:
            errorCode = TLBaseServiceErrorCodeNoStorageSpace;
            break;
            
        case 15:
            errorCode = TLBaseServiceErrorCodeNoPermission;
            break;
            
        case 16:
            errorCode = TLBaseServiceErrorCodeLimitReached;
            break;
            
        case 17:
            errorCode = TLBaseServiceErrorCodeDatabaseError;
            break;

        case 18:
            errorCode = TLBaseServiceErrorCodeQueued;
            break;

        case 19:
            errorCode = TLBaseServiceErrorCodeQueuedNoWakeup;
            break;

        case 20:
            errorCode = TLBaseServiceErrorCodeExpired;
            break;

        case 21:
            errorCode = TLBaseServiceErrorCodeInvalidPublicKey;
            break;

        case 22:
            errorCode = TLBaseServiceErrorCodeInvalidPrivateKey;
            break;

        case 23:
            errorCode = TLBaseServiceErrorCodeNoPublicKey;
            break;

        case 24:
            errorCode = TLBaseServiceErrorCodeNoPrivateKey;
            break;

        case 25:
            errorCode = TLBaseServiceErrorCodeBadSignature;
            break;

        case 26:
            errorCode = TLBaseServiceErrorCodeBadSignatureFormat;
            break;

        case 27:
            errorCode = TLBaseServiceErrorCodeBadSignatureMissingAttribute;
            break;

        case 28:
            errorCode = TLBaseServiceErrorCodeBadSignatureNotSignedAttribute;
            break;

        case 29:
            errorCode = TLBaseServiceErrorCodeEncryptError;
            break;

        case 30:
            errorCode = TLBaseServiceErrorCodeDecryptError;
            break;

        case 31:
            errorCode = TLBaseServiceErrorCodeBadEncryptionFormat;
            break;

        case 32:
            errorCode = TLBaseServiceErrorCodeNoSecretKey;
            break;

        case 33:
            errorCode = TLBaseServiceErrorCodeNotEncrypted;
            break;

        default:
            errorCode = TLBaseServiceErrorCodeLibraryTooOld;
    }

    return errorCode;
}

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    @synchronized(self) {
        NSMutableSet *delegates = [NSMutableSet setWithSet:self.delegates];
        [delegates addObject:delegate];
        self.delegates = delegates;
    }
}

- (void)removeDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    @synchronized(self) {
        NSMutableSet *delegates = [NSMutableSet setWithSet:self.delegates];
        [delegates removeObject:delegate];
        self.delegates = delegates;
    }
}

- (TLBaseServiceId)getBaseServiceId {
    
    return self.serviceConfiguration.baseServiceId;
}

- (nonnull NSString *)getVersion {
    
    return self.serviceConfiguration.version;
}

- (nonnull NSString *)getServiceName {
    DDLogVerbose(@"%@ getServiceName", LOG_TAG);
    
    return SERVICE_NAMES[self.getBaseServiceId];
}

- (nonnull TLServiceStats *)getServiceStats {
    DDLogVerbose(@"%@ getServiceStats", LOG_TAG);
    
    int sendCount, sendErrorCount, sendDisconnectedCount, sendTimeoutCount;
    sendCount = _sendCount;
    sendErrorCount = _sendErrorCount;
    sendDisconnectedCount = _sendDisconnectedCount;
    sendTimeoutCount = _sendTimeoutCount;

    TLServiceStats *stats = [[TLServiceStats alloc] initWithCount:sendCount errorCount:sendErrorCount disconnectedCount:sendDisconnectedCount timeoutCount:sendTimeoutCount];
    return [self getDatabaseStatsWithServiceStats:stats];
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super init];
    if (self) {
        _twinlife = twinlife;
        _serviceConfiguration = [[TLBaseServiceConfiguration alloc] init];
        _delegates = [[NSSet alloc] init];
        _databaseFullCount = 0L;
        _databaseErrorCount = 0L;
        _jobService = [twinlife jobService];
        _pendingRequestIdList = [[NSMutableSet alloc] init];
        _sendCount = 0L;
        _sendErrorCount = 0L;
        _sendDisconnectedCount = 0L;
        _sendTimeoutCount = 0L;
    }
    return self;
}

- (void)configure:(nonnull TLBaseServiceConfiguration*)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
}

- (BOOL)activate:(nonnull TLServerConnection *)stream {
    DDLogVerbose(@"%@ activate: %@", LOG_TAG, stream);
    
    self.serverStream = stream;
    return NO;
}

- (uint64_t)timestamp {
    
    return mach_absolute_time();
}

- (BOOL)isSignIn {
    DDLogVerbose(@"%@ isSignIn %d", LOG_TAG, self.signIn);
    
    return self.signIn;
}

- (BOOL)isTwinlifeOnline {
    DDLogVerbose(@"%@ isTwinlifeOnline %d", LOG_TAG, self.online);
    
    return [self.twinlife isTwinlifeOnline];
}

- (void)onCreate {
    DDLogVerbose(@"%@ onCreate", LOG_TAG);
}

- (void)onConfigure {
    DDLogVerbose(@"%@ onConfigure", LOG_TAG);
}

- (void)onUpdateConfigurationWithConfiguration:(TLBaseServiceImplConfiguration *)configuration {
    DDLogVerbose(@"%@ onUpdateConfigurationWithConfiguration: %@", LOG_TAG, configuration);
}

- (void)onDestroy {
    DDLogVerbose(@"%@ onDestroy", LOG_TAG);
}

- (void)onConnect {
    DDLogVerbose(@"%@ onConnect", LOG_TAG);
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    self.signIn = NO;
    self.online = NO;

    NSSet<TLRequestInfo *> *timeoutRequestIds = nil;
    @synchronized (self) {
        if (self.pendingRequestIdList.count > 0) {
            timeoutRequestIds = self.pendingRequestIdList;
            self.pendingRequestIdList = [[NSMutableSet alloc] init];
        }
        if (self.scheduleJobId) {
            [self.scheduleJobId cancel];
            self.scheduleJobId = nil;
        }
    }

    // We have some requestIds for the timeout, raise the onErrorWithRequestId delegates.
    if (timeoutRequestIds) {
        [self timeoutWithRequestIds:timeoutRequestIds];
    }
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    self.signIn = YES;
}

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onSignInErrorWithErrorCode: %d", LOG_TAG, errorCode);
    
    self.signIn = NO;
    self.online = NO;
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    self.signIn = NO;
    self.online = NO;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
}

- (void)onTwinlifeResume {
    DDLogVerbose(@"%@ onTwinlifeResume", LOG_TAG);
    
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    self.online = YES;
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onErrorWithRequestId:errorCode:errorParameter:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [delegate onErrorWithRequestId:requestId errorCode:errorCode errorParameter:errorParameter];
            });
        }
    }
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);
    
}

- (TLBaseServiceErrorCode)onDatabaseErrorWithError:(nonnull NSError *)error line:(int)line {
    DDLogVerbose(@"%@ onDatabaseErrorWithError: %@", LOG_TAG, error);
    
    TLBaseServiceErrorCode errorCode;
    if (error.code == SQLITE_FULL) {
        atomic_fetch_add(&_databaseFullCount, 1);
        errorCode = TLBaseServiceErrorCodeNoStorageSpace;
    } else {
        atomic_fetch_add(&_databaseErrorCount, 1);
        errorCode = TLBaseServiceErrorCodeDatabaseError;
        [self.twinlife assertionWithAssertPoint:[TLTwinlifeAssertPoint DATABASE_ERROR], [TLAssertValue initWithNumber:(int)error.code], [TLAssertValue initWithLine:line], [TLAssertValue initWithServiceId:[self getBaseServiceId]], nil];
    }
    
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    if (now < self.lastDatabaseErrorTime + DATABASE_ERROR_DELAY_GUARD ) {
        return errorCode;
    }
    
    self.lastDatabaseErrorTime = now;
    [self.twinlife errorWithErrorCode:errorCode errorParameter:[error localizedDescription]];
    return errorCode;
}

- (TLBaseServiceErrorCode)onDatabaseErrorWithCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDatabaseErrorWithCode: %d", LOG_TAG, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeNoStorageSpace) {
        atomic_fetch_add(&_databaseFullCount, 1);
    } else {
        atomic_fetch_add(&_databaseErrorCount, 1);
    }
    
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    if (now < self.lastDatabaseErrorTime + DATABASE_ERROR_DELAY_GUARD ) {
        return errorCode;
    }
    
    self.lastDatabaseErrorTime = now;
    [self.twinlife errorWithErrorCode:errorCode errorParameter:nil];
    return errorCode;
}

- (nonnull TLServiceStats *)getDatabaseStatsWithServiceStats:(nonnull TLServiceStats *)stats {
    DDLogVerbose(@"%@ getDatabaseStatsWithServiceStats: %@", LOG_TAG, stats);
    
    int databaseFullCount, databaseErrorCount;
    do {
        databaseFullCount = _databaseFullCount;
    } while (!atomic_compare_exchange_strong(&_databaseFullCount, &databaseFullCount, 0));
    do {
        databaseErrorCount = _databaseErrorCount;
    } while (!atomic_compare_exchange_strong(&_databaseErrorCount, &databaseErrorCount, 0));
    
    stats.databaseFullCount = databaseFullCount;
    stats.databaseErrorCount = databaseErrorCount;
    return stats;
}

- (void)sendBinaryIQ:(nonnull TLBinaryPacketIQ *)iq factory:(nonnull TLSerializerFactory *)factory timeout:(NSTimeInterval)timeout {

    if (self.signIn) {
        [self packetTimeout:iq.requestId timeout:timeout isBinary:YES];
        NSData *data = [iq serializeCompactWithSerializerFactory:factory];
        if ([self.serverStream sendWithData:data]) {
            atomic_fetch_add(&_sendCount, 1);
            return;
        }

        // packetTimeout must be called before sendWithData but it can fail and we must now clean the request list.
        [self receivedBinaryIQ:iq];
    }

    // Failed miserably...
    atomic_fetch_add(&_sendDisconnectedCount, 1);
        
    [self onErrorWithErrorPacket:[[TLBinaryErrorPacketIQ alloc] initWithSerializer:[TLTwinlife IQ_ON_ERROR_SERIALIZER] requestId:iq.requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline]];
}

- (void)sendResponseIQ:(nonnull TLBinaryPacketIQ *)iq factory:(nonnull TLSerializerFactory *)factory {

    if (self.signIn) {
        NSData *data = [iq serializeCompactWithSerializerFactory:factory];
        if ([self.serverStream sendWithData:data]) {
            atomic_fetch_add(&_sendCount, 1);
        } else {
            atomic_fetch_add(&_sendDisconnectedCount, 1);
        }
    } else {
        atomic_fetch_add(&_sendDisconnectedCount, 1);
    }
}

- (void)packetTimeout:(int64_t)requestId timeout:(NSTimeInterval)timeout isBinary:(BOOL)isBinary {

    TLRequestInfo *requestInfo = [[TLRequestInfo alloc] initWithRequestId:requestId isBinary:isBinary];
    NSDate *deadline = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout + TIMEOUT_CHECK_DELAY];
    @synchronized (self) {
        [self.pendingRequestIdList addObject:requestInfo];
        self.nextDeadline = deadline;
        if (!self.scheduleJobId) {
            self.scheduleJobId = [self.jobService scheduleWithJob:self deadline:deadline priority:TLJobPriorityMessage];
        }
    }
}

- (void)receivedBinaryIQ:(nonnull TLBinaryPacketIQ *)iq {
    
    TLRequestInfo *requestInfo = [[TLRequestInfo alloc] initWithRequestId:iq.requestId isBinary:YES];
    @synchronized (self) {
        [self.pendingRequestIdList removeObject:requestInfo];
        if (self.pendingRequestIdList.count == 0 && self.scheduleJobId) {
            [self.scheduleJobId cancel];
            self.scheduleJobId = nil;
        }
    }
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    NSDate *now = [NSDate date];
    NSSet<TLRequestInfo *> *timeoutRequestIds = nil;
    @synchronized (self) {
        self.scheduleJobId = nil;
        if ([self.nextDeadline compare:now] <= NSOrderedSame) {
            if (self.pendingRequestIdList.count > 0) {
                timeoutRequestIds = self.pendingRequestIdList;
                self.pendingRequestIdList = [[NSMutableSet alloc] init];
            }
        } else {
            self.scheduleJobId = [self.jobService scheduleWithJob:self deadline:self.nextDeadline priority:TLJobPriorityMessage];
        }
    }

    // We have some requestIds for the timeout.
    if (timeoutRequestIds) {
        [self timeoutWithRequestIds:timeoutRequestIds];
    }
}

- (void)timeoutWithRequestIds:(nonnull NSSet<TLRequestInfo *> *)requestIds {
    DDLogVerbose(@"%@ timeoutWithRequestIds", LOG_TAG);

    for (TLRequestInfo *requestId in requestIds) {
        atomic_fetch_add(&_sendTimeoutCount, 1);

        if (requestId.isBinary) {
            [self onErrorWithErrorPacket:[[TLBinaryErrorPacketIQ alloc] initWithSerializer:[TLTwinlife IQ_ON_ERROR_SERIALIZER] requestId:requestId.requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline]];
        } else {
            [self onErrorWithRequestId:requestId.requestId errorCode:TLBaseServiceErrorCodeTwinlifeOffline errorParameter:nil];
        }
    }
}

@end

