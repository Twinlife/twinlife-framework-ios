/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLBaseServiceImpl.h"
#import "TLDatabaseService.h"
#import "TLTwincodeFactoryServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLAttributeNameValue.h"
#import "TLCreateTwincodeIQ.h"
#import "TLDeleteTwincodeIQ.h"
#import "TLOnCreateTwincodeIQ.h"
#import "TLBinaryErrorPacketIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define TWINCODE_FACTORY_SERVICE_VERSION @"2.2.0"

#define CREATE_TWINCODE_SCHEMA_ID         @"8184d22a-980c-40a3-90c3-02ff4732e7b9"
#define ON_CREATE_TWINCODE_SCHEMA_ID      @"6c0442f5-b0bf-4b7e-9ae5-40ad720b1f71"
#define DELETE_TWINCODE_SCHEMA_ID         @"cf8f2889-4ee2-4e50-a26a-5cbd475bb07a"
#define ON_DELETE_TWINCODE_SCHEMA_ID      @"311945f8-24c5-451c-aee3-bcd154aca963"

static TLBinaryPacketIQSerializer *IQ_CREATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_TWINCODE_SERIALIZER = nil;

//
// Implementation: TLTwincodeFactory
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeFactory"

@implementation TLTwincodeFactory

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)uuid modificationDate:(int64_t)modificationDate twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeSwitchId:(nonnull NSUUID *)twincodeSwitchId attributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ initWithUUID: %@", LOG_TAG, uuid);
    
    self = [super initWithUUID:uuid modificationDate:modificationDate attributes:attributes];
    if (self) {
        _twincodeInbound = twincodeInbound;
        _twincodeOutbound = twincodeOutbound;
        _twincodeSwitchId = twincodeSwitchId;
    }
    return self;
}

- (TLTwincodeFacet)getFacet {
    
    return TWINCODE_FACTORY;
}

- (BOOL)isTwincodeFactory {
    
    return YES;
}

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLTwincodeFactory class]]) {
        return NO;
    }
    TLTwincodeFactory* twincodeFactory = (TLTwincodeFactory *) object;
    return [twincodeFactory.uuid isEqual:self.uuid] && twincodeFactory.modificationDate == self.modificationDate;
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.uuid.hash;
    return result;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincodeFactory\n"];
    [string appendFormat:@" id: %@\n", [self.uuid UUIDString]];
    [string appendFormat:@" modificationDate: %lld\n", self.modificationDate];
    [string appendFormat:@" twincodeInboundId: %@\n", [self.twincodeInbound.objectId UUIDString]];
    [string appendFormat:@" twincodeOutboundId: %@\n", [self.twincodeOutbound.objectId UUIDString]];
    [string appendFormat:@" twincodeSwitchId: %@\n", [self.twincodeSwitchId UUIDString]];
    [string appendString:@" attributes:\n"];
    for (TLAttributeNameValue* attribute in self.attributes) {
        [string appendFormat:@" %@: %@\n", attribute.name, attribute.value];
    }
    return string;
}

@end

#pragma mark - TLFactoryPendingRequest

//
// Implementation: TLFactoryPendingRequest
//

@implementation TLFactoryPendingRequest

@end

//
// Implementation: TLCreateFactoryPendingRequest
//

@implementation TLCreateFactoryPendingRequest

-(nonnull instancetype)initWithFactoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes complete:(nonnull TLCreateTwincodeFactoryComplete)complete {
    DDLogVerbose(@"%@ initWithFactoryAttributes: %@", LOG_TAG, factoryAttributes);

    self = [super init];
    if (self) {
        // Note: we must copy the factory attributes.  The inbound and outbound attributes don't need
        // the copy because we will import them with importWithAttributes.
        _factoryAttributes = [[NSMutableArray alloc] initWithCapacity:factoryAttributes.count];
        [_factoryAttributes addObjectsFromArray:factoryAttributes];
        _inboundAttributes = inboundAttributes;
        _outboundAttributes = outboundAttributes;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLDeleteFactoryPendingRequest
//

@implementation TLDeleteFactoryPendingRequest

-(nonnull instancetype)initWithFactoryId:(nonnull NSUUID *)factoryId complete:(nonnull TLDeleteTwincodeFactoryComplete)complete {
    DDLogVerbose(@"%@ initWithFactoryId: %@", LOG_TAG, factoryId);

    self = [super init];
    if (self) {
        _factoryId = factoryId;
        _complete = complete;
    }
    return self;
}

@end

#pragma mark - TLTwincodeFactoryService

//
// Implementation: TLTwincodeFactoryServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeFactoryServiceConfiguration"

@implementation TLTwincodeFactoryServiceConfiguration

- (nonnull instancetype) init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdTwincodeFactoryService version:[TLTwincodeFactoryService VERSION] serviceOn:NO];
}

@end

//
// Interface: TLTwincodeFactoryService
//

@interface TLTwincodeFactoryService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLFactoryPendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLCryptoService *cryptoService;

@end

//
// Implementation: TLTwincodeFactoryService
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeFactoryService"

@implementation TLTwincodeFactoryService

+ (void)initialize {

    IQ_CREATE_TWINCODE_SERIALIZER = [[TLCreateTwincodeIQSerializer alloc] initWithSchema:CREATE_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_CREATE_TWINCODE_SERIALIZER = [[TLOnCreateTwincodeIQSerializer alloc] initWithSchema:ON_CREATE_TWINCODE_SCHEMA_ID schemaVersion:1];
    IQ_DELETE_TWINCODE_SERIALIZER = [[TLDeleteTwincodeIQSerializer alloc] initWithSchema:DELETE_TWINCODE_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_TWINCODE_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_DELETE_TWINCODE_SCHEMA_ID schemaVersion:1];
}

+ (nonnull NSString *)VERSION {

    return TWINCODE_FACTORY_SERVICE_VERSION;
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    if (self) {
    
        _serializerFactory = twinlife.serializerFactory;
        _pendingRequests = [[NSMutableDictionary alloc] init];
        _cryptoService = [twinlife getCryptoService];

        // Register the binary IQ handlers for the responses.
        [twinlife addPacketListener:IQ_ON_CREATE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onCreateTwincodeWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteTwincodeWithIQ:iq];
        }];
    }

    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLTwincodeFactoryServiceConfiguration* twincodeFactoryServiceConfiguration = [[TLTwincodeFactoryServiceConfiguration alloc] init];
    TLTwincodeFactoryServiceConfiguration* serviceConfiguration = (TLTwincodeFactoryServiceConfiguration *) baseServiceConfiguration;
    twincodeFactoryServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = twincodeFactoryServiceConfiguration;
    self.serviceOn = twincodeFactoryServiceConfiguration.isServiceOn;
}

#pragma mark - TLTwincodeFactoryService

- (void)createTwincodeWithFactoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes switchAttributes:(nullable NSArray<TLAttributeNameValue *> *)switchAttributes twincodeSchemaId:(nonnull NSUUID *)twincodeSchemaId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *_Nullable twincodeFactory))block {
    DDLogVerbose(@"%@: createTwincodeWithFactoryAttributes: %@ twincodeSchemaId: %@", LOG_TAG, factoryAttributes, twincodeSchemaId);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLCreateFactoryPendingRequest alloc] initWithFactoryAttributes:factoryAttributes inboundAttributes:inboundAttributes outboundAttributes:outboundAttributes complete:block];
    }

    TLCreateTwincodeIQ *iq = [[TLCreateTwincodeIQ alloc] initWithSerializer:IQ_CREATE_TWINCODE_SERIALIZER requestId:requestId.longLongValue createOptions:BIND_INBOUND_OPTION factoryAttributes:factoryAttributes inboundAttributes:inboundAttributes outboundAttributes:nil switchAttributes:switchAttributes twincodeSchemaId:twincodeSchemaId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)deleteTwincodeWithFactoryId:(nonnull NSUUID *)twincodeFactoryId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable twincodeFactoryId))block {
    DDLogVerbose(@"%@: deleteTwincodeWithFactoryId: %@", LOG_TAG, twincodeFactoryId);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLDeleteFactoryPendingRequest alloc] initWithFactoryId:twincodeFactoryId complete:block];
    }

    TLDeleteTwincodeIQ *iq = [[TLDeleteTwincodeIQ alloc] initWithSerializer:IQ_DELETE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeFactoryId deleteOptions:0];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

#pragma mark - TLTwincodeFactoryService()

- (void)onCreateTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnCreateTwincodeIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnCreateTwincodeIQ *onCreateTwincodeIQ = (TLOnCreateTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLCreateFactoryPendingRequest *request;
    @synchronized (self) {
        request = (TLCreateFactoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    TLDatabaseService *database = self.twinlife.databaseService;
    __block TLTwincodeFactory *twincodeFactory = nil;
    [database inTransaction:^(TLTransaction *transaction) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        TLTwincodeOutbound *twincodeOutbound = [transaction storeTwincodeOutboundWithTwincode:onCreateTwincodeIQ.outboundTwincodeId attributes:request.outboundAttributes flags:TWINCODE_CREATE_FLAGS modificationDate:now refreshPeriod:0 refreshDate:0 refreshTimestamp:0];
        TLTwincodeInbound *twincodeInbound = [transaction storeTwincodeInboundWithTwincode:onCreateTwincodeIQ.inboundTwincodeId twincodeOutbound:twincodeOutbound twincodeFactoryId:onCreateTwincodeIQ.factoryTwincodeId attributes:request.inboundAttributes modificationDate:now];

        [self.cryptoService createPrivateKeyWithTransaction:transaction twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound];
        [transaction commit];
        twincodeFactory = [[TLTwincodeFactory alloc] initWithUUID:onCreateTwincodeIQ.factoryTwincodeId modificationDate:now twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeSwitchId:onCreateTwincodeIQ.switchTwincodeId attributes:request.factoryAttributes];
    }];

    if (twincodeFactory) {
        if (request.outboundAttributes) {
            // Update the twincode outbound with the attributes after the creation
            // so that these attributes are signed.
            [[self.twinlife getTwincodeOutboundService] updateTwincodeWithTwincode:twincodeFactory.twincodeOutbound attributes:request.outboundAttributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                request.complete(errorCode, twincodeFactory);
            }];
        } else {
            request.complete(TLBaseServiceErrorCodeSuccess, twincodeFactory);
        }
    } else {
        request.complete(TLBaseServiceErrorCodeNoStorageSpace, nil);
    }
}

- (void)onDeleteTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onDeleteTwincodeWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLDeleteFactoryPendingRequest *request;
    @synchronized (self) {
        request = (TLDeleteFactoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    [self removeTwincodeWithFactoryId:request.factoryId];

    request.complete(TLBaseServiceErrorCodeSuccess, request.factoryId);
}

- (void)removeTwincodeWithFactoryId:(nonnull NSUUID *)factoryId {
    DDLogVerbose(@"%@ removeTwincodeWithFactoryId: %@", LOG_TAG, factoryId);

    TLDatabaseService *database = self.twinlife.databaseService;
    [database inTransaction:^(TLTransaction *transaction) {
        FMResultSet *resultSet = [transaction executeQuery:@"SELECT ti.id, ti.twincodeId, twout.id, twout.twincodeId"
                                      " FROM twincodeInbound AS ti "
                                      " LEFT JOIN twincodeOutbound AS twout ON ti.twincodeOutbound = twout.id"
                                      " WHERE ti.factoryId=?", [factoryId toString]];
        if (!resultSet) {
            [self onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            int64_t databaseId = [resultSet longLongIntForColumnIndex:0];
            [transaction deleteWithDatabaseId:databaseId table:TLDatabaseTableTwincodeInbound];
            [database evictCacheWithObjectId:[resultSet uuidForColumnIndex:1]];

            databaseId = [resultSet longLongIntForColumnIndex:2];
            [transaction deleteWithDatabaseId:databaseId table:TLDatabaseTableTwincodeKeys];
            [transaction deleteWithDatabaseId:databaseId table:TLDatabaseTableSecretKeys];
            [transaction deleteWithDatabaseId:databaseId table:TLDatabaseTableTwincodeOutbound];
            [database evictCacheWithObjectId:[resultSet uuidForColumnIndex:3]];
        }
        [resultSet close];
        [transaction commit];
    }];
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);
    
    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLFactoryPendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized(self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    // The object no longer exists on the server, remove it from our local database.
    if ([request isKindOfClass:[TLCreateFactoryPendingRequest class]]) {
        TLCreateFactoryPendingRequest *createPendingRequest = (TLCreateFactoryPendingRequest *)request;

        createPendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLDeleteFactoryPendingRequest class]]) {
        TLDeleteFactoryPendingRequest *deletePendingRequest = (TLDeleteFactoryPendingRequest *)request;

        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self removeTwincodeWithFactoryId:deletePendingRequest.factoryId];
        }
        deletePendingRequest.complete(errorCode, nil);

    }
}

@end
