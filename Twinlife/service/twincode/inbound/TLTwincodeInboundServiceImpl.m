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

#import "TLBaseServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLRepositoryServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLAttributeNameValue.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLGetTwincodeIQ.h"
#import "TLOnGetTwincodeIQ.h"
#import "TLUpdateTwincodeIQ.h"
#import "TLOnUpdateTwincodeIQ.h"
#import "TLRefreshTwincodeIQ.h"
#import "TLOnRefreshTwincodeIQ.h"
#import "TLInvokeTwincodeIQ.h"
#import "TLInvocationIQ.h"
#import "TLAcknowledgeInvocationIQ.h"
#import "TLTriggerPendingInvocationsIQ.h"
#import "TLBinaryErrorPacketIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define TWINCODE_INBOUND_SERVICE_VERSION          @"3.3.1"

#define GET_TWINCODE_SCHEMA_ID                    @"22903c9e-545f-44f4-948b-908b3153cfc2"
#define ON_GET_TWINCODE_SCHEMA_ID                 @"177b0d15-2d19-4e89-8e16-701f7266ab48"
#define UPDATE_TWINCODE_SCHEMA_ID                 @"77a5bf4e-8f4c-4772-b100-4344d44fadde"
#define ON_UPDATE_TWINCODE_SCHEMA_ID              @"887BF747-7995-456E-AA72-34B7E7C53160"
#define TRIGGER_PENDING_INVOCATIONS_SCHEMA_ID     @"266f3d93-1782-491c-b6cb-28cc23df4fdf"
#define ON_TRIGGER_PENDING_INVOCATIONS_SCHEMA_ID  @"b70ac369-54c9-4f42-8217-59e6f52bb8fc"
#define ACKNOWLEDGE_INVOCATION_SCHEMA_ID          @"eee63e5e-8af1-41e9-9a1b-79806a0056a2"
#define ON_ACKNOWLEDGE_INVOCATION_SCHEMA_ID       @"5d57d54b-2d03-4ad7-9a77-75b9b3373715"
#define INVOKE_TWINCODE_SCHEMA_ID                 @"c74e79e6-5157-4fb4-bad8-2de545711fa0"
#define ON_INVOKE_TWINCODE_SCHEMA_ID              @"35d11e72-84d7-4a3b-badd-9367ef8c9e43"
#define BIND_TWINCODE_SCHEMA_ID                   @"afa1a19e-2af9-409d-8502-4a77e29b1d91"
#define ON_BIND_TWINCODE_SCHEMA_ID                @"4ffd7362-498d-4584-9d93-49d7514a6c32"
#define UNBIND_TWINCODE_SCHEMA_ID                 @"7fad2e67-c6b9-4925-96ed-9af3bb83d19f"
#define ON_UNBIND_TWINCODE_SCHEMA_ID              @"3d791a6d-6ad0-438c-89cf-92a822a85846"

static TLBinaryPacketIQSerializer *IQ_GET_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_UPDATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_UPDATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TRIGGER_PENDING_INVOCATIONS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_TRIGGER_PENDING_INVOCATIONS_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ACKNOWLEDGE_INVOCATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_ACKNOWLEDGE_INVOCATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_INVOKE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_INVOKE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_BIND_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_BIND_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_UNBIND_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_UNBIND_TWINCODE_SERIALIZER = nil;

//
// Interface: TLPendingInvocation ()
//
// Record a list of invocations being processed for a specific twincode inbound id.
// A list of code blocks is recorded in case the `waitInvocationsForTwincode()` wants
// to execute some code and it will be executed when every invocation for that twincode
// has been processed.

typedef void (^TLWaitingCodeBlock) (void);

@interface TLPendingInvocation : NSObject

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSMutableArray<NSUUID *> *invocationList;
@property (readonly, nullable, weak) id<TLRepositoryObject> subject;
@property (nullable) NSMutableArray<TLWaitingCodeBlock> *waitingCodeBlocks;
@property (nullable) NSMutableArray<TLTwincodeInvocation *> *waitingInvocations;

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId invocationId:(nonnull NSUUID *)invocationId subject:(nonnull id<TLRepositoryObject>)subject;

-(BOOL)queueWithInvocation:(nonnull TLTwincodeInvocation *)invocation;

@end

//
// Implementation: TLPendingInvocation ()
//

#undef LOG_TAG
#define LOG_TAG @"TLPendingInvocation"

@implementation TLPendingInvocation

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId invocationId:(nonnull NSUUID *)invocationId subject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ initWithTwincodeId: %@ invocationId: %@", LOG_TAG, twincodeId, invocationId);

    self = [super init];
    if (self) {
        _twincodeId = twincodeId;
        _invocationList = [[NSMutableArray alloc] init];
        _subject = subject;
        _waitingInvocations = nil;
        [_invocationList addObject:invocationId];
    }
    return self;
}

-(BOOL)queueWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@ queueWithInvocation: %@", LOG_TAG, invocation);

    // If the first invocationId in `invocationList` is the invocation, we don't need to queue
    // and we can execute immediately.
    if (self.invocationList.count == 0 || [invocation.invocationId isEqual:self.invocationList[0]]) {
        return NO;
    }
    
    if (!self.waitingInvocations) {
        self.waitingInvocations = [[NSMutableArray alloc] init];
    }
    [self.waitingInvocations addObject:invocation];
    return YES;
}

@end

//
// Implementation: TLGetInboundTwincodePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLGetInboundTwincodePendingRequest"

@implementation TLGetInboundTwincodePendingRequest

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound complete:(nonnull TLInboundTwincodeConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincodeId: %@ twincodeOutbound: %@", LOG_TAG, twincodeId, twincodeOutbound);

    self = [super init];
    if (self) {
        _twincodeId = twincodeId;
        _twincodeOutbound = twincodeOutbound;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLBindUnbindTwincodePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLBindUnbindTwincodePendingRequest"

@implementation TLBindUnbindTwincodePendingRequest

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeInbound *)twincode complete:(nonnull TLInboundTwincodeConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincode: %@", LOG_TAG, twincode);

    self = [super init];
    if (self) {
        _twincode = twincode;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLTriggerInvocationsPendingRequest ()
//

@implementation TLTriggerInvocationsPendingRequest

-(nonnull instancetype)initWithComplete:(nonnull TLTriggerInvocationConsumer)complete {
    DDLogVerbose(@"%@ initWithComplete: %@", LOG_TAG, complete);

    self = [super init];
    if (self) {
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLUpdateInboundTwincodePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateInboundTwincodePendingRequest"

@implementation TLUpdateInboundTwincodePendingRequest

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeInbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes complete:(nonnull TLInboundTwincodeConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincode: %@", LOG_TAG, twincode);

    self = [super init];
    if (self) {
        _twincode = twincode;
        _attributes = attributes;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLTwincodeInbound
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInbound"

@implementation TLTwincodeInbound

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId factoryId:(nullable NSUUID *)factoryId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ twincodeId: %@ modificationDate: %lld capabilities: %@ content: %@", LOG_TAG, identifier, twincodeId, modificationDate, capabilities, content);
    
    self = [super initWithUUID:twincodeId modificationDate:modificationDate attributes:nil];
    if (self) {
        _databaseId = identifier;
        _factoryId = factoryId;
        _twincodeOutbound = twincodeOutbound;
        [self updateWithCapabilities:capabilities content:content modificationDate:modificationDate];
    }
    return self;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ twincodeId: %@ modificationDate: %lld attributes: %@", LOG_TAG, identifier, twincodeId, modificationDate, attributes);
    
    self = [super initWithUUID:twincodeId modificationDate:modificationDate attributes:nil];
    if (self) {
        _databaseId = identifier;
        [self importWithAttributes:attributes modificationDate:modificationDate];
    }
    return self;
}

- (void)updateWithCapabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ updateWithCapabilities: %@ content: %@", LOG_TAG, capabilities, content);

    NSMutableArray<TLAttributeNameValue *> *attributes = [TLBinaryCompactDecoder deserializeWithData:content];
    @synchronized (self) {
        self.capabilities = capabilities;
        self.modificationDate = modificationDate;
        self.attributes = attributes;
    }
}

- (void)importWithAttributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ importWithAttributes: %@ modificationDate: %lld", LOG_TAG, attributes, modificationDate);

    @synchronized (self) {
        self.modificationDate = modificationDate;
        for (TLAttributeNameValue *attribute in attributes) {
            if ([attribute.name isEqualToString:@"capabilities"]) {
                self.capabilities = (NSString *)((TLAttributeNameStringValue*)attribute.value);
            } else {
                BOOL found = NO;
                if (self.attributes) {
                    for (TLAttributeNameValue *existingAttr in self.attributes) {
                        if ([attribute.name isEqualToString:existingAttr.name]) {
                            existingAttr.value = attribute.value;
                            found = YES;
                        }
                    }
                }
                if (!found) {
                    if (!self.attributes) {
                        self.attributes = [[NSMutableArray alloc] init];
                    }
                    [self.attributes addObject:attribute];
                }
            }
        }
    }
}

- (nullable NSData *)serialize {
    
    @synchronized (self) {
        return [TLBinaryCompactEncoder serializeWithAttributes:self.attributes];
    }
}

- (TLTwincodeFacet)getFacet {
    
    return TWINCODE_INBOUND;
}

- (BOOL)isTwincodeInbound {
    
    return YES;
}

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.databaseId;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

- (nullable NSUUID *)twincodeFactoryId {
    
    return self.factoryId;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincodeInbound["];
    [string appendFormat:@" id: %@", [self.identifier description]];
    [string appendFormat:@" modificationDate: %lld", self.modificationDate];
    if (self.attributes) {
        [string appendString:@" attributes:"];
        for (TLAttributeNameValue* attribute in self.attributes) {
            [string appendFormat:@" %@: %@", attribute.name, attribute.value];
        }
    }
    [string appendString:@"]"];
    return string;
}

@end

//
// Implementation: TLTwincodeInvocation
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInvocation"

@implementation TLTwincodeInvocation

- (nonnull instancetype) initWithInvocationId:(nonnull NSUUID *)invocationId subject:(nonnull id<TLRepositoryObject>)subject action:(nonnull NSString *)action attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod {
    
    self = [super init];
    if (self) {
        _invocationId = invocationId;
        _subject = subject;
        _action = action;
        _attributes = attributes;
        _peerTwincodeId = peerTwincodeId;
        _keyIndex = keyIndex;
        _secretKey = secretKey;
        _publicKey = publicKey;
        _trustMethod = trustMethod;
    }
    return self;
}

- (nonnull NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincodeInvocation["];
    [string appendFormat:@" id: %@", self.invocationId];
    [string appendFormat:@" action: %@", self.action];
    if (self.publicKey) {
        [string appendFormat:@" publicKey: %@", self.publicKey];
        [string appendFormat:@" keyIndex: %d", self.keyIndex];
    }
    if (self.attributes) {
        [string appendString:@" attributes:"];
        for (TLAttributeNameValue* attribute in self.attributes) {
            [string appendFormat:@" %@: %@", attribute.name, attribute.value];
        }
    }
    [string appendString:@"]"];
    return string;
}

@end

//
// Implementation: TLTwincodeInboundServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInboundServiceConfiguration"

@implementation TLTwincodeInboundServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdTwincodeInboundService version:[TLTwincodeInboundService VERSION] serviceOn:NO];
}

@end

//
// Interface: TLTwincodeInboundService
//

@interface TLTwincodeInboundService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLTwincodePendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLTwincodeInboundServiceProvider *serviceProvider;
@property (readonly, nonnull) TLCryptoService *cryptoService;
@property (readonly, nonnull) NSMutableDictionary<NSString *, TLTwincodeInvocationListener> *invocationListeners;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, TLPendingInvocation *> *pendingInvocations;

@end

//
// Implementation: TLTwincodeInboundService
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInboundService"

@implementation TLTwincodeInboundService

+ (nonnull NSString *)VERSION {
    
    return TWINCODE_INBOUND_SERVICE_VERSION;
}

+ (void)initialize {
    
    IQ_GET_TWINCODE_SERIALIZER = [[TLGetTwincodeIQSerializer alloc] initWithSchema:GET_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_GET_TWINCODE_SERIALIZER = [[TLOnGetTwincodeIQSerializer alloc] initWithSchema:ON_GET_TWINCODE_SCHEMA_ID schemaVersion:2];

    IQ_UPDATE_TWINCODE_SERIALIZER = [[TLUpdateTwincodeIQSerializer alloc] initWithSchema:UPDATE_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_UPDATE_TWINCODE_SERIALIZER = [[TLOnUpdateTwincodeIQSerializer alloc] initWithSchema:ON_UPDATE_TWINCODE_SCHEMA_ID schemaVersion:1];

    IQ_INVOKE_TWINCODE_SERIALIZER = [[TLInvokeTwincodeIQSerializer alloc] initWithSchema:INVOKE_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_INVOKE_TWINCODE_SERIALIZER = [[TLInvocationIQSerializer alloc] initWithSchema:ON_INVOKE_TWINCODE_SCHEMA_ID schemaVersion:1];

    IQ_TRIGGER_PENDING_INVOCATIONS_SERIALIZER = [[TLTriggerPendingInvocationsIQSerializer alloc] initWithSchema:TRIGGER_PENDING_INVOCATIONS_SCHEMA_ID schemaVersion:2];
    IQ_ON_TRIGGER_PENDING_INVOCATIONS_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_TRIGGER_PENDING_INVOCATIONS_SCHEMA_ID schemaVersion:1];

    IQ_ACKNOWLEDGE_INVOCATION_SERIALIZER = [[TLAcknowledgeInvocationIQSerializer alloc] initWithSchema:ACKNOWLEDGE_INVOCATION_SCHEMA_ID schemaVersion:2];
    IQ_ON_ACKNOWLEDGE_INVOCATION_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_ACKNOWLEDGE_INVOCATION_SCHEMA_ID schemaVersion:1];

    IQ_BIND_TWINCODE_SERIALIZER = [[TLGetTwincodeIQSerializer alloc] initWithSchema:BIND_TWINCODE_SCHEMA_ID schemaVersion:1];
    IQ_ON_BIND_TWINCODE_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_BIND_TWINCODE_SCHEMA_ID schemaVersion:1];

    IQ_UNBIND_TWINCODE_SERIALIZER = [[TLGetTwincodeIQSerializer alloc] initWithSchema:UNBIND_TWINCODE_SCHEMA_ID schemaVersion:1];
    IQ_ON_UNBIND_TWINCODE_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_UNBIND_TWINCODE_SCHEMA_ID schemaVersion:1];

}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    _serviceProvider = [[TLTwincodeInboundServiceProvider alloc] initWithService:self database:twinlife.databaseService];
    _serializerFactory = twinlife.serializerFactory;
    _pendingRequests = [[NSMutableDictionary alloc] init];
    _cryptoService = twinlife.cryptoService;
    _invocationListeners = [[NSMutableDictionary alloc] init];
    _pendingInvocations = [[NSMutableDictionary alloc] init];

    // Register the binary IQ handler for incoming invoke twincode forwarded by the server.
    [twinlife addPacketListener:IQ_INVOKE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onInvokeTwincodeWithIQ:iq];
    }];

    // Register the binary IQ handlers for the responses.
    [twinlife addPacketListener:IQ_ON_GET_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onGetTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_UPDATE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onUpdateTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_BIND_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onBindTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_UNBIND_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onUnbindTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_ACKNOWLEDGE_INVOCATION_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAcknowledgeInvocationWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_TRIGGER_PENDING_INVOCATIONS_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onTriggerPendingInvocationsWithIQ:iq];
    }];

    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLTwincodeInboundServiceConfiguration* twincodeInboundServiceConfiguration = [[TLTwincodeInboundServiceConfiguration alloc] init];
    TLTwincodeInboundServiceConfiguration* serviceConfiguration = (TLTwincodeInboundServiceConfiguration *) baseServiceConfiguration;
    twincodeInboundServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = twincodeInboundServiceConfiguration;
    self.serviceOn = twincodeInboundServiceConfiguration.isServiceOn;
}

#pragma mark - TLTwincodeInboundService

- (void)addListenerWithAction:(nonnull NSString *)action listener:(nonnull TLTwincodeInvocationListener)listener {
    DDLogVerbose(@"%@: addListenerWithAction: %@ listener: %@", LOG_TAG, action, listener);

    [self.invocationListeners setObject:listener forKey:action];
}

- (void)getTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeinbound))block {
    DDLogVerbose(@"%@: getTwincodeWithTwincodeId: %@ twincodeOutbound: %@", LOG_TAG, twincodeInboundId, twincodeOutbound);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    TLTwincodeInbound *twincodeInbound = [self.serviceProvider loadTwincodeWithTwincodeId:twincodeInboundId];
    if (twincodeInbound) {
        dispatch_async([self.twinlife twinlifeQueue], ^{
            block(TLBaseServiceErrorCodeSuccess, twincodeInbound);
        });
    } else {
        NSNumber *requestId = [TLBaseService newRequestId];
        @synchronized(self) {
            self.pendingRequests[requestId] = [[TLGetInboundTwincodePendingRequest alloc] initWithTwincodeId:twincodeInboundId twincodeOutbound:twincodeOutbound complete:block];
        }

        TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_GET_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeInboundId];
        [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    }
}

- (void)bindTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInboundId))block {
    DDLogVerbose(@"%@: bindTwincodeWithTwincode: %@", LOG_TAG, twincodeInbound);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLBindUnbindTwincodePendingRequest alloc] initWithTwincode:twincodeInbound complete:block];
    }

    TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_BIND_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeInbound.objectId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)unbindTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInbound))block {
    DDLogVerbose(@"%@: unbindTwincodeWithTwincode: %@", LOG_TAG, twincodeInbound);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLBindUnbindTwincodePendingRequest alloc] initWithTwincode:twincodeInbound complete:block];
    }

    TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_UNBIND_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeInbound.objectId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInbound))block {
    DDLogVerbose(@"%@: updateTwincodeWithTwincode: %@ attributes: %@ deleteAttributeNames: %@", LOG_TAG, twincodeInbound, attributes, deleteAttributeNames);
    
    if (!self.serviceOn) {
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLUpdateInboundTwincodePendingRequest alloc] initWithTwincode:twincodeInbound attributes:attributes complete:block];
    }

    TLUpdateTwincodeIQ *iq = [[TLUpdateTwincodeIQ alloc] initWithSerializer:IQ_UPDATE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeInbound.objectId attributes:attributes deleteAttributeNames:nil signature:nil];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)acknowledgeInvocationWithInvocationId:(nonnull NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@: acknowledgeInvocationWithInvocationId: %@ errorCode: %d", LOG_TAG, invocationId, errorCode);
    
    if (!self.serviceOn) {
        return;
    }
    
    // We must not return ITEM_NOT_FOUND if some element of the invocation is not available because
    // the server will invalidate the inbound twincode.  The only place where we can return it is
    // from onInvokeTwincode() and only when the inbound twincode was not associated with a valid subject.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        errorCode = TLBaseServiceErrorCodeExpired;
    }
    
    NSNumber *requestId = [TLBaseService newRequestId];
    TLAcknowledgeInvocationIQ *iq = [[TLAcknowledgeInvocationIQ alloc] initWithSerializer:IQ_ACKNOWLEDGE_INVOCATION_SERIALIZER requestId:requestId.longLongValue invocationId:invocationId errorCode:errorCode];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];

    [self finishInvocationWithId:invocationId];
}

- (void)triggerPendingInvocationsWithFilters:(nullable NSArray<NSString *> *)filters withBlock:(nonnull void (^)(void))block {
    DDLogVerbose(@"%@: triggerPendingInvocationsWithFilters: %@", LOG_TAG, filters);
    
    if (!self.serviceOn) {
        return;
    }
    
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLTriggerInvocationsPendingRequest alloc] initWithComplete:block];
    }

    TLTriggerPendingInvocationsIQ *iq = [[TLTriggerPendingInvocationsIQ alloc] initWithSerializer:IQ_TRIGGER_PENDING_INVOCATIONS_SERIALIZER requestId:requestId.longLongValue filters:filters];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)waitInvocationsForTwincode:(nonnull NSUUID *)twincodeId withBlock:(nonnull void (^) (void))block {
    DDLogVerbose(@"%@: waitInvocationsForTwincode: %@", LOG_TAG, twincodeId);

    // If we have pending invocations, check if there is one for the given twincode inbound.
    // When found, the code block is appended to the waiting list and will be executed when
    // all invocations are processed.  The number of invocations received is in most cases
    // zero or one and rarely exceeds 5.
    @synchronized (self) {
        if (self.pendingInvocations.count > 0) {
            for (TLPendingInvocation *checkInvocation in self.pendingInvocations.allValues) {
                if ([twincodeId isEqual:checkInvocation.twincodeId]) {
                    DDLogError(@"%@: queue block for twincode: %@", LOG_TAG, twincodeId);

                    if (!checkInvocation.waitingCodeBlocks) {
                        checkInvocation.waitingCodeBlocks = [[NSMutableArray alloc] init];
                    }
                    [checkInvocation.waitingCodeBlocks addObject:block];
                    return;
                }
            }
        }
    }

    block();
}

- (BOOL)hasPendingInvocations {
    
    @synchronized (self) {
        return self.pendingInvocations.count > 0;
    }
}

#pragma mark - TLTwincodeInboundService ()

- (void)finishInvocationWithId:(nonnull NSUUID *)invocationId {
    DDLogVerbose(@"%@: finishInvocationWithId: %@", LOG_TAG, invocationId);

    TLPendingInvocation* pendingInvocation;
    TLTwincodeInvocation *invocation;
    NSMutableArray<TLWaitingCodeBlock> *waitingCodeBlocks;
    @synchronized (self) {
        pendingInvocation = self.pendingInvocations[invocationId];
        if (!pendingInvocation) {
            return;
        }
        [self.pendingInvocations removeObjectForKey:invocationId];
        [pendingInvocation.invocationList removeObject:invocationId];
        
        if (!pendingInvocation.waitingInvocations || pendingInvocation.waitingInvocations.count == 0) {
            invocation = nil;
            waitingCodeBlocks = pendingInvocation.invocationList.count > 0 ? nil : pendingInvocation.waitingCodeBlocks;
        } else {
            invocation = pendingInvocation.waitingInvocations[0];
            [pendingInvocation.waitingInvocations removeObjectAtIndex:0];
            waitingCodeBlocks = nil;
        }
    }

    if (invocation) {
        [self executeWithInvocation:invocation];
    }

    // All invocation have been processed, if we have some code blocks execute them.
    if (waitingCodeBlocks) {
        for (TLWaitingCodeBlock block in waitingCodeBlocks) {
            block();
        }
    }
}

- (void)onGetTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnGetTwincodeIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnGetTwincodeIQ *onGetTwincodeIQ = (TLOnGetTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLGetInboundTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLGetInboundTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!request.twincodeId) {
        return;
    }

    TLTwincodeInbound *twincodeInbound = [self.serviceProvider importTwincodeWithTwincodeId:request.twincodeId twincodeOutbound:request.twincodeOutbound attributes:onGetTwincodeIQ.attributes modificationDate:onGetTwincodeIQ.modificationDate];

    request.complete(twincodeInbound ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, twincodeInbound);
}

- (void)onUpdateTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onUpdateTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnUpdateTwincodeIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnUpdateTwincodeIQ *onUpdateTwincodeIQ = (TLOnUpdateTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLUpdateInboundTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLUpdateInboundTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    [self.serviceProvider updateTwincodeWithTwincode:request.twincode attributes:request.attributes modificationDate:onUpdateTwincodeIQ.modificationDate];
    request.complete(TLBaseServiceErrorCodeSuccess, request.twincode);
}

- (void)onBindTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onBindTwincodeWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLBindUnbindTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLBindUnbindTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    request.complete(TLBaseServiceErrorCodeSuccess, request.twincode);
}

- (void)onUnbindTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onUnbindTwincodeWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLBindUnbindTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLBindUnbindTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    request.complete(TLBaseServiceErrorCodeSuccess, request.twincode);
}

- (void)onInvokeTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onInvokeTwincodeWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLInvokeTwincodeIQ class]]) {
        return;
    }

    // If we are suspended or going to suspend, do not handle any incoming invocation:
    // since we don't respond, the server will send a Push APNS notification to wakeup
    // the device and we will handle it at that time.
    if ([self.twinlife status] != TLTwinlifeStatusStarted) {
        return;
    }
    
    TLInvokeTwincodeIQ *invokeTwincodeIQ = (TLInvokeTwincodeIQ *)iq;
    NSUUID *invocationId = invokeTwincodeIQ.invocationId;
    if (!invocationId) {
        return;
    }

    TLPendingInvocation* pendingInvocation;
    NSUUID *key = invokeTwincodeIQ.twincodeId;
    id<TLRepositoryObject> subject;
    @synchronized (self) {
        // Check if the invocation is already being processed.
        // This occurs if we disconnect and re-connect before having time to process the invocation.
        pendingInvocation = self.pendingInvocations[invocationId];
        if (pendingInvocation) {
            return;
        }

        // Check for another invocation on the same twincode (this is rare but it happens
        // and must be handled for waitInvocationsForTwincode).
        for (TLPendingInvocation *checkInvocation in self.pendingInvocations.allValues) {
            if ([key isEqual:checkInvocation.twincodeId]) {
                pendingInvocation = checkInvocation;
                [pendingInvocation.invocationList addObject:invocationId];
                [self.pendingInvocations setObject:pendingInvocation forKey:invocationId];
                subject = checkInvocation.subject;
                break;
            }
        }
    }

    // And if we know the subject, no need to look again in the database.
    if (!subject) {
        subject = [[self.twinlife getRepositoryService] findObjectWithKey:key];
        if (!subject) {
            // Send the ITEM_NOT_FOUND error so that the server is aware we don't recognize the twincode inbound anymore.
            NSNumber *requestId = [TLBaseService newRequestId];
            TLAcknowledgeInvocationIQ *iq = [[TLAcknowledgeInvocationIQ alloc] initWithSerializer:IQ_ACKNOWLEDGE_INVOCATION_SERIALIZER requestId:requestId.longLongValue invocationId:invocationId errorCode:TLBaseServiceErrorCodeItemNotFound];
            [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];

            // Finish manually this invocation.
            [self finishInvocationWithId:invocationId];
            return;
        }
    }

    TLTwincodeInvocation *invocation;
    if (invokeTwincodeIQ.data) {
        TLDecipherResult *decipherResult = [self.cryptoService decryptWithTwincode:subject.twincodeOutbound encrypted:invokeTwincodeIQ.data];
        if (decipherResult.errorCode != TLBaseServiceErrorCodeSuccess) {
            [self acknowledgeInvocationWithInvocationId:invocationId errorCode:decipherResult.errorCode];
            return;
        }
        invocation = [[TLTwincodeInvocation alloc] initWithInvocationId:invocationId subject:subject action:invokeTwincodeIQ.actionName attributes:decipherResult.attributes peerTwincodeId:decipherResult.peerTwincodeId keyIndex:decipherResult.keyIndex secretKey:decipherResult.secretKey publicKey:decipherResult.publicKey trustMethod:decipherResult.trustMethod];
    } else {
        invocation = [[TLTwincodeInvocation alloc] initWithInvocationId:invocationId subject:subject action:invokeTwincodeIQ.actionName attributes:invokeTwincodeIQ.attributes peerTwincodeId:nil keyIndex:0 secretKey:nil publicKey:nil trustMethod:TLTrustMethodNone];
    }

    // This twincode is having its first invocation, remember it.
    BOOL queued;
    if (!pendingInvocation) {
        pendingInvocation = [[TLPendingInvocation alloc] initWithTwincodeId:key invocationId:invocationId subject:subject];

        @synchronized (self) {
            [self.pendingInvocations setObject:pendingInvocation forKey:invocation.invocationId];
        }
        queued = NO;
    } else {
        @synchronized (self) {
            queued = [pendingInvocation queueWithInvocation:invocation];
        }
    }
    if (!queued) {
        [self executeWithInvocation:invocation];
    }
}

- (void)executeWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: executeWithInvocation: %@", LOG_TAG, invocation);

    // A twincode invocation can be handled by only one handler because we have to respond:
    // - if the handler returns TLBaseServiceErrorCodeQueued, it must acknowledge itself the invocation,
    // - otherwise the invocation is acknowledged with the returned code.
    TLTwincodeInvocationListener listener = self.invocationListeners[invocation.action];
    if (!listener) {
        [self acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:TLBaseServiceErrorCodeBadRequest];
        return;
    }
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLBaseServiceErrorCode errorCode = listener(invocation);
        if (errorCode != TLBaseServiceErrorCodeQueued) {
#if defined(DEBUG) && DEBUG == 1
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                DDLogError(@"%@: Invocation '%@' failed: %d", LOG_TAG, invocation.action, errorCode);
            }
#endif
            [self acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
        }
    });
}

- (void)onAcknowledgeInvocationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onAcknowledgeInvocationWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];
}

- (void)onTriggerPendingInvocationsWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@: onTriggerPendingInvocationsWithIQ: %@", LOG_TAG, iq);
    
    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLTriggerInvocationsPendingRequest *request;
    @synchronized (self) {
        request = (TLTriggerInvocationsPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    request.complete();
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);
    
    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLTwincodePendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized(self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    // The object no longer exists on the server, remove it from our local database.
    if ([request isKindOfClass:[TLGetInboundTwincodePendingRequest class]]) {
        TLGetInboundTwincodePendingRequest *getTwincodePendingRequest = (TLGetInboundTwincodePendingRequest *)request;

        getTwincodePendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLUpdateInboundTwincodePendingRequest class]]) {
        TLUpdateInboundTwincodePendingRequest *updateTwincodePendingRequest = (TLUpdateInboundTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self.serviceProvider deleteWithObject:updateTwincodePendingRequest.twincode];
        }
        updateTwincodePendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLBindUnbindTwincodePendingRequest class]]) {
        TLBindUnbindTwincodePendingRequest *bindUnbindPendingRequest = (TLBindUnbindTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self.serviceProvider deleteWithObject:bindUnbindPendingRequest.twincode];
        }
        bindUnbindPendingRequest.complete(errorCode, nil);

    }
}

@end
