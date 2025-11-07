/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import "TLPeerConnectionHandler.h"
#import "TLBinaryPacketIQ.h"
#import "TLBinaryCompactDecoder.h"
#import "TLSerializerFactoryImpl.h"
#import "TLAccountService.h"
#import "TLPeerConnectionServiceImpl.h"
#import "TLVersion.h"
#import "TLJobService.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

/**
 * P2P connection management for the account migration service between two peers.
 *
 * Protocol version 2.1.0 - iOS support
 *  Date: 2024/07/09
 *    AccountSecuredConfiguration has a new schema version 4 that we must use if the peer supports 2.1.0
 *    but we should send the schema version 3 if the peer is using 2.0.0.  This fallback mechanism is not allows from iOS.
 *    The goal is to allow users which are sticked to Android 4.x (twinme 17.3) to be able to migrate to a newer version.
 *
 * Protocol version 2.0.0
 *  Date: 2021/12/01
 *    AccountSecuredConfiguration has a new schema version 3.
 *    Incrementing the protocol version allows to refuse the migration with an old device that only supports schema version 2.
 *    (if we do this, the account transfer will not work).
 *    The user must first upgrade the old device.
 *
 * Protocol version 1.0.0
 *  Date: 2020/11/23
 *    Android migration Twinme, Twinme+
 */
#define VERSION_PREFIX @"AccountMigration."
#define VERSION @"2.1.0"
#define MIN_PROTOCOL_VERSION 2
#define MIN_MINOR_VERSION 1

#define CONNECT_TIMEOUT 20
#define RECONNECT_TIMEOUT 10

//
// Interface: TLPeerConnectionHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnectionHandler"

@interface TLPeerConnectionHandler ()

@property (nonatomic, readonly) BOOL padding;
@property (nonatomic) BOOL isOnline;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLBinaryPacketListener> *binaryPacketListeners;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSNumber *> *pendingRequests;

@property (nonatomic, nullable) NSUUID *incomingPeerConnectionId;
@property (nonatomic, nullable) NSUUID *outgoingPeerConnectionId;

@property (nonatomic, readonly, nonnull) NSString *peerId;

@property (nonatomic, nullable) TLJobId *reconnectTimeoutJobId;
@property (nonatomic, nullable) TLJobId *openTimeoutJobId;

@property (readonly, nonnull) void *processQueueTag;
@property (nonatomic, nullable) dispatch_queue_t processQueue;

- (void)startOutgoingConnection;
- (void) onOpenTimeout;
@end

//
// Interface: TLReconnectTimeoutHandler
//

@interface TLReconnectTimeoutHandler : NSObject <TLJob>

@property (weak) TLPeerConnectionHandler *peerConnectionHandler;

- (nonnull instancetype)initWithPeerConnectionHandler:(nonnull TLPeerConnectionHandler *)peerConnectionHandler;

- (void)runJob;
@end


//
// Implementation: TLReconnectTimeoutHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLReconnectTimeoutHandler"

@implementation TLReconnectTimeoutHandler

- (nonnull instancetype)initWithPeerConnectionHandler:(nonnull TLPeerConnectionHandler *)peerConnectionHandler {
    DDLogVerbose(@"%@ initWithPeerConnectionHandler: %@", LOG_TAG, peerConnectionHandler);
    
    self = [super init];
    
    if (self) {
        _peerConnectionHandler = peerConnectionHandler;
    }
    
    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    [self.peerConnectionHandler startOutgoingConnection];
}
@end

//
// Interface: TLOpenTimeoutHandler
//

@interface TLOpenTimeoutHandler : NSObject <TLJob>

@property (weak) TLPeerConnectionHandler *peerConnectionHandler;

- (nonnull instancetype)initWithPeerConnectionHandler:(nonnull TLPeerConnectionHandler *)peerConnectionHandler;

- (void)runJob;
@end

//
// Implementation: TLOpenTimeoutHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLOpenTimeoutHandler"

@implementation TLOpenTimeoutHandler

- (nonnull instancetype)initWithPeerConnectionHandler:(nonnull TLPeerConnectionHandler *)peerConnectionHandler {
    DDLogVerbose(@"%@ initWithPeerConnectionHandler: %@", LOG_TAG, peerConnectionHandler);
    
    self = [super init];
    
    if (self) {
        _peerConnectionHandler = peerConnectionHandler;
    }
    
    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    [self.peerConnectionHandler onOpenTimeout];
}



@end


//
// Implementation: TLPeerConnectionHandler
//

@implementation TLPeerConnectionHandler


- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife peerId:(nonnull NSString *)peerId {
    DDLogVerbose(@"%@ initWithTwinlife", LOG_TAG);
    
    self = [super init];
    if (self) {
        _twinlife = twinlife;
        _peerId = peerId;
        _peerConnectionService = twinlife.peerConnectionService;
        _serializerFactory = twinlife.serializerFactory;
        _binaryPacketListeners = [[NSMutableDictionary alloc] init];
        _padding = NO;
        _isOnline = twinlife.accountService.isTwinlifeOnline;
        _pendingRequests = [[NSMutableSet alloc] init];
        [_peerConnectionService addDelegate:self];
        
        _processQueueTag = &_processQueueTag;
        dispatch_queue_attr_t attr;
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        _processQueue = dispatch_queue_create("closeConnectionQueue", attr);
        dispatch_queue_set_specific(_processQueue, _processQueueTag, _processQueueTag, NULL);
    }
    return self;
}

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener {
    DDLogVerbose(@"%@ addPacketListener: %@", LOG_TAG, serializer);
    
    TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
    self.binaryPacketListeners[key] = listener;
    [self.serializerFactory addSerializer:serializer];
}

- (void)startOutgoingConnection {
    DDLogVerbose(@"%@ startOutgoingConnection", LOG_TAG);
    
    TLOffer *offer = [[TLOffer alloc] initWithAudio:NO video:NO videoBell:NO data:YES];
    TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:NO video:NO data:YES];
    
    TLNotificationContent *notificationContent = [[TLNotificationContent alloc] initWithPriority:TLPeerConnectionServiceNotificationPriorityHigh operation:TLPeerConnectionServiceNotificationOperationPushFile timeToLive:0];
    
    @synchronized (self.pendingRequests) {
        if (self.reconnectTimeoutJobId) {
            [self.reconnectTimeoutJobId cancel];
            self.reconnectTimeoutJobId = nil;
        }

        if (self.openTimeoutJobId) {
            [self.openTimeoutJobId cancel];
            self.openTimeoutJobId = nil;
        }
        
        if (!self.isOnline) {
            return;
        }

        [self scheduleOpenTimeoutJob];
    }
    
    [self.peerConnectionService createOutgoingPeerConnectionWithPeerId:self.peerId offer:offer offerToReceive:offerToReceive notificationContent:notificationContent dataChannelDelegate:self delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *peerConnectionId) {
        if (peerConnectionId) {
            @synchronized (self.pendingRequests) {
                self.outgoingPeerConnectionId = peerConnectionId;
            }
        }
    }];
}

- (void)startIncomingConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ startIncomingConnection", LOG_TAG);

    @synchronized (self.pendingRequests) {
        
        self.incomingPeerConnectionId = peerConnectionId;
    }
    
    TLOffer *offer = [[TLOffer alloc] initWithAudio:NO video:NO videoBell:NO data:YES];
    TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:NO video:NO data:YES];
    
    [self.peerConnectionService createIncomingPeerConnectionWithPeerConnectionId:peerConnectionId offer:offer offerToReceive:offerToReceive dataChannelDelegate:self delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *uuid) {

    }];
}

/// Close the P2P connection during the shutdown state.

- (void)closeConnection {
    DDLogVerbose(@"%@ closeConnection", LOG_TAG);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), self.processQueue, ^{
        NSUUID *peerConnectionId;
        
        @synchronized (self.pendingRequests) {
            peerConnectionId = self.peerConnectionId;
        }
        
        if (peerConnectionId) {
            [self terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonSuccess];
        }
    });
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    BOOL isConnected;
    @synchronized (self.pendingRequests) {
        self.isOnline = YES;
        isConnected = self.peerConnectionId != nil;
    }
    
    if (!isConnected) {
        [self startOutgoingConnection];
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    @synchronized (self.pendingRequests) {
        self.isOnline = NO;
            
        if (self.reconnectTimeoutJobId) {
            [self.reconnectTimeoutJobId cancel];
            self.reconnectTimeoutJobId = nil;
        }
    }
}

- (void)finish {
    DDLogVerbose(@"%@ finish", LOG_TAG);
    
    NSUUID *incomingPeerConnectionId;
    NSUUID *outgoingPeerConnectionId;
    
    @synchronized (self.pendingRequests) {
        incomingPeerConnectionId = self.incomingPeerConnectionId;
        outgoingPeerConnectionId = self.outgoingPeerConnectionId;
        self.peerConnectionId = nil;
        self.incomingPeerConnectionId = nil;
        self.outgoingPeerConnectionId = nil;
        
        if (self.openTimeoutJobId) {
            [self.openTimeoutJobId cancel];
            self.openTimeoutJobId = nil;
        }
        
        if (self.reconnectTimeoutJobId) {
            [self.reconnectTimeoutJobId cancel];
            self.reconnectTimeoutJobId = nil;
        }
    }
    
    [self.peerConnectionService removeDelegate:self];
    
    if (incomingPeerConnectionId) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:incomingPeerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonCancel];
    }

    if (outgoingPeerConnectionId) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:outgoingPeerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonCancel];
    }
    
    self.processQueue = nil;
}

#pragma mark - PeerConnectionServiceDelegate

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ onTerminatePeerConnectionWithPeerConnectionId: %@ terminateReason:%d", LOG_TAG, peerConnectionId, terminateReason);
    
    BOOL isConnected;
    
    @synchronized (self.pendingRequests) {
        BOOL initiator = self.outgoingPeerConnectionId != nil;
        
        if ([peerConnectionId isEqual:self.incomingPeerConnectionId]) {
            self.incomingPeerConnectionId = nil;
        } else if ([peerConnectionId isEqual:self.outgoingPeerConnectionId]) {
            self.outgoingPeerConnectionId = nil;
        } else {
            return;
        }
        
        if ([peerConnectionId isEqual:self.peerConnectionId]) {
            self.peerConnectionId = nil;
        }
        
        if (self.openTimeoutJobId) {
            [self.openTimeoutJobId cancel];
            self.openTimeoutJobId = nil;
        }
        
        if (self.reconnectTimeoutJobId) {
            [self.reconnectTimeoutJobId cancel];
            self.reconnectTimeoutJobId = nil;
        }
        
        // If ze qre disconnected, still online and we're the initator, setup the reconnection timer.
        isConnected = self.peerConnectionId != nil;
        if (self.isOnline && !isConnected && initiator) {
            [self scheduleReconnectJob];
        }
    }
    
    if (!isConnected) {
        [self onTerminateWithTerminateReason:terminateReason];
    }

}

- (void)onAcceptPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer { 
    
}

- (void)onAddLocalAudioTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull TL_RTCRtpSender *)sender audioTrack:(nonnull TL_RTCAudioTrack *)audioTrack { 
    
}

- (void)onAddRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId mediaTrack:(nonnull TL_RTCMediaStreamTrack *)mediaTrack { 
    
}

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state { 
    
}

- (void)onPeerHoldCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId { 
    
}

- (void)onPeerResumeCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId { 
    
}

- (void)onRemoveLocalSenderWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull TL_RTCRtpSender *)sender { 
    
}

- (void)onRemoveRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId trackId:(nonnull NSString *)trackId { 
    
}

- (nonnull TLPeerConnectionDataChannelConfiguration *)configurationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sdpEncryptionStatus:(TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus {
    DDLogVerbose(@"%@ configurationWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    NSString *version = [VERSION_PREFIX stringByAppendingString:VERSION];
    return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:version leadingPadding:self.padding];
}

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelOpenWithPeerConnectionId: %@ peerVersion: %@", LOG_TAG, peerConnectionId, peerVersion);
    
    if (![peerVersion hasPrefix:VERSION_PREFIX]) {
        return;
    }
    
    BOOL isValid = [self checkPeerVersionWithVersion:peerVersion];
    
    @synchronized (self.pendingRequests) {
        // Check for the incoming or outgoing P2P connection and remember which connection we are connected.
        if ([peerConnectionId isEqual:self.incomingPeerConnectionId]) {
            if (isValid) {
                self.peerConnectionId = self.incomingPeerConnectionId;
            }
        } else if ([peerConnectionId isEqual:self.outgoingPeerConnectionId]) {
            if (isValid) {
                self.peerConnectionId = self.outgoingPeerConnectionId;
            }
        } else {
            return;
        }
        
        if (self.openTimeoutJobId) {
            [self.openTimeoutJobId cancel];
            self.openTimeoutJobId = nil;
        }
    }
    
    if (!isValid) {
        [self terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonNotAuthorized];
        return;
    }
    
    [self onDataChannelOpen];
}

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onDataChannelClosedWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    @synchronized (self.pendingRequests) {
        if (![peerConnectionId isEqual:self.incomingPeerConnectionId] && ![peerConnectionId isEqual:self.outgoingPeerConnectionId]) {
            return;
        }
    }
    
    [self terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError];
}

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelMessageWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    NSUUID *schemaId;
    int schemaVersion;
    @try {
        TLBinaryDecoder *binaryDecoder;
        if (leadingPadding) {
            binaryDecoder = [[TLBinaryDecoder alloc] initWithData:data];
        } else {
            binaryDecoder = [[TLBinaryCompactDecoder alloc] initWithData:data];
        }
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
        TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:schemaId schemaVersion:schemaVersion];
        TLSerializer *serializer = [self.serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
        TLBinaryPacketListener listener = self.binaryPacketListeners[key];

        if (!listener || !serializer) {
            DDLogWarn(@"%@ onDataChannelMessageWithPeerConnectionId: schema unsupported: %@.%d", LOG_TAG, schemaId, schemaVersion);
        } else {
            NSObject *object = [serializer deserializeWithSerializerFactory:self.serializerFactory decoder:binaryDecoder];
            if (![object isKindOfClass:[TLBinaryPacketIQ class]]) {
                DDLogError(@"%@ onDataChannelMessageWithPeerConnectionId: invalid packet", LOG_TAG);
            } else {
                TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)object;
                listener(iq);
            }
        }
    }
    @catch(NSException *lException) {
        DDLogError(@"%@ onDataChannelMessageWithPeerConnectionId: exception: %@ schemaId: %@", LOG_TAG, lException, schemaId);
    }
}

- (BOOL)sendMessageWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ sendMessageWithIQ: %@ statType: %d", LOG_TAG, iq, statType);
    
    NSUUID *peerConnectionId = self.peerConnectionId;
    if (!peerConnectionId) {
        return NO;
    }
    
    [self.peerConnectionService sendPacketWithPeerConnectionId:peerConnectionId statType:statType iq:iq];
    
    return YES;
}

- (void) onOpenTimeout {
    DDLogVerbose(@"%@ onOpenTimeout", LOG_TAG);

    NSUUID *peerConnectionId = nil;
    BOOL isConnected;
    
    @synchronized (self.pendingRequests) {
        self.openTimeoutJobId = nil;
        
        if (self.outgoingPeerConnectionId) {
            peerConnectionId = self.outgoingPeerConnectionId;
        } else if (self.incomingPeerConnectionId) {
            peerConnectionId = self.incomingPeerConnectionId;
        } else {
            peerConnectionId = nil;
        }
        
        // Schedule an automatic reconnection in 10 seconds
        if (self.reconnectTimeoutJobId) {
            [self.reconnectTimeoutJobId cancel];
            self.reconnectTimeoutJobId = nil;
        }
        
        // If we are disconnected and still online, setup the reconnection timer.
        isConnected = self.peerConnectionId != nil;
        
        if (self.isOnline && !isConnected) {
            [self scheduleReconnectJob];
        }
    }
    
    if (peerConnectionId) {
        [self terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonTimeout];
    }
    
    if (!isConnected) {
        [self onTimeout];
    }
}

- (void)onTerminateWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason{
    DDLogVerbose(@"%@ onTerminateWithTerminateReason:%d", LOG_TAG, terminateReason);
}

- (BOOL) checkPeerVersionWithVersion:(nullable NSString *)peerVersion {
    DDLogVerbose(@"%@ checkPeerVersionWithVersion: %@", LOG_TAG, peerVersion);
    
    if (!peerVersion) {
        return NO;
    }

    // peerVersion = i.j.k
    NSRange index = [peerVersion rangeOfString:@"."];
    if (index.length == 0) {
        return NO;
    }

    TLVersion *version = [[TLVersion alloc] initWithVersion:[peerVersion substringFromIndex:index.location + 1]];
    if (version.major < MIN_PROTOCOL_VERSION) {
        DDLogError(@"%@ Protocol version %@ is not supported", LOG_TAG, peerVersion);
        return NO;
    }
    // Don't accept 2.0 from iOS: it is not possible to use an old Android version for the migration.
    if (version.major == MIN_PROTOCOL_VERSION && version.minor < MIN_MINOR_VERSION) {
        DDLogError(@"%@ Protocol version %@ is not supported", LOG_TAG, peerVersion);
        return NO;
    }
    return YES;
}

- (void) terminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ terminatePeerConnectionWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);

    [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
    
    [self onTerminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
    
}

- (void) scheduleReconnectJob {
    TLReconnectTimeoutHandler *handler = [[TLReconnectTimeoutHandler alloc] initWithPeerConnectionHandler:self];
    
    self.reconnectTimeoutJobId = [[self.twinlife getJobService] scheduleWithJob:handler delay:RECONNECT_TIMEOUT priority:TLJobPriorityMessage];
}

- (void) scheduleOpenTimeoutJob {
    TLOpenTimeoutHandler *handler = [[TLOpenTimeoutHandler alloc] initWithPeerConnectionHandler:self];
    
    self.openTimeoutJobId = [[self.twinlife getJobService] scheduleWithJob:handler delay:CONNECT_TIMEOUT priority:TLJobPriorityMessage];
}

- (void)onDataChannelOpen {
    DDLogVerbose(@"%@ onDataChannelOpen", LOG_TAG);
    
}

- (void)onTimeout {
    DDLogVerbose(@"%@ onTimeout", LOG_TAG);
    
}

@end
