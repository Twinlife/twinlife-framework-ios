/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>
#include <stdatomic.h>

#import <WebRTC/RTCIceServer.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCCameraVideoCapturer.h>
#import <WebRTC/RTCVideoSource.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCFieldTrials.h>
#import <WebRTC/RTCLogging.h>
#import <WebRTC/RTCDefaultVideoDecoderFactory.h>
#import <WebRTC/RTCDefaultVideoEncoderFactory.h>
#import <WebRTC/RTCVideoDecoderFactory.h>
#import <WebRTC/RTCVideoEncoderFactory.h>
#import <WebRTC/RTCPeerConnection.h>

#import "TLPeerConnectionServiceImpl.h"
#import "TLProxyDescriptor.h"
#import "TLCryptoServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLRepositoryServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLBaseServiceImpl.h"
#import "TLPeerConnection.h"
#import "TLJobService.h"
#import "TLSdp.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define PEER_CONNECTION_SERVICE_VERSION @"2.2.3"

#define EVENT_ID_REPORT_QUALITY @"twinlife::peerConnectionService::quality"

static const int MAX_VIDEO_WIDTH = 640;
static const int MAX_VIDEO_HEIGHT = 480;
static const int MAX_VIDEO_FRAME_RATE = 30;
static const int MIN_VIDEO_FRAME_RATE = 10;

static NSData *PEER_CONNECTION_SERVICE_LEADING_PADDING;

//
// Interface: TLPeerConnectionService ()
//

@interface TLPeerConnectionService ()

@property atomic_int closeQueuedCount;
@property atomic_int closeCount;
@property atomic_int closeDoneCount;
@property atomic_int dataFactoryCreateCount;
@property atomic_int dataFactoryDeleteCount;
@property atomic_int mediaFactoryCreateCount;
@property atomic_int mediaFactoryDeleteCount;
@property (nullable) RTC_OBJC_TYPE(RTCPeerConnectionFactory) *dataConnectionFactory;
@property (nullable) RTC_OBJC_TYPE(RTCPeerConnectionFactory) *mediaConnectionFactory;
@property (readonly, nonnull) dispatch_queue_t cleaningQueue;
@property (readonly, nonnull) void *executorQueueTag;
@property RTC_OBJC_TYPE(RTCVideoTrack) *videoTrack;
@property (nullable) RTC_OBJC_TYPE(RTCCameraVideoCapturer) *videoCapturer;
@property (nullable) RTC_OBJC_TYPE(RTCVideoSource) *videoSource;

@end

//
// Implementation: TLPeerConnectionDataChannelConfiguration
//

@implementation TLPeerConnectionDataChannelConfiguration

- (nonnull instancetype)initWithVersion:(nonnull NSString *)version leadingPadding:(BOOL)leadingPadding {
    
    self = [super init];
    if (self) {
        _version = version;
        _leadingPadding = leadingPadding;
    }
    return self;
}

@end

//
// Implementation: TLOffer
//

@implementation TLOffer

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video videoBell:(BOOL)videoBell data:(BOOL)data {
    
    self = [super init];
    if (self) {
        _audio = audio;
        _video = video;
        _videoBell = videoBell;
        _data = data;
        _group = false;
        _transfer = false;
    }
    return self;
}

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video videoBell:(BOOL)videoBell data:(BOOL)data group:(BOOL)group transfer:(BOOL)transfer version:(nonnull TLVersion *)version {
    
    self = [super init];
    if (self) {
        _audio = audio;
        _video = video;
        _videoBell = videoBell;
        _data = data;
        _group = group;
        _transfer = transfer;
        _version = version;
    }
    return self;
}

@end

//
// Implementation: TLOfferToReceive
//

@implementation TLOfferToReceive

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video data:(BOOL)data {
    
    self = [super init];
    
    _audio = audio;
    _video = video;
    _data = data;
    return self;
}

@end

//
// Implementation: TLNotificationContent
//

@implementation TLNotificationContent

- (nonnull instancetype)initWithPriority:(TLPeerConnectionServiceNotificationPriority)priority operation:(TLPeerConnectionServiceNotificationOperation)operation timeToLive:(int)timeToLive {
    
    self = [super init];
    _priority = priority;
    _operation = operation;
    _timeToLive = timeToLive;
    return self;
}

@end

//
// Implementation: TLPeerConnectionServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnectionServiceConfiguration"

@implementation TLPeerConnectionServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdPeerConnectionService version:[TLPeerConnectionService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLPeerConnectionService
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnectionService"

@implementation TLPeerConnectionService

+ (void)initialize {
    
    int8_t b = 0;
    PEER_CONNECTION_SERVICE_LEADING_PADDING = [NSData dataWithBytes:&b length:1];
}

+ (nonnull NSString *)VERSION {
    
    return PEER_CONNECTION_SERVICE_VERSION;
}

+ (nonnull NSData *)LEADING_PADDING {
    
    return PEER_CONNECTION_SERVICE_LEADING_PADDING;
}

+ (nonnull NSString *)terminateReasonToString:(TLPeerConnectionServiceTerminateReason)terminateReason {
    
    switch (terminateReason) {
        case TLPeerConnectionServiceTerminateReasonBusy:
            return @"busy";
        case TLPeerConnectionServiceTerminateReasonCancel:
            return @"cancel";
        case TLPeerConnectionServiceTerminateReasonConnectivityError:
            return @"connectivity-error";
        case TLPeerConnectionServiceTerminateReasonDecline:
            return @"decline";
        case TLPeerConnectionServiceTerminateReasonDisconnected:
            return @"disconnected";
        case TLPeerConnectionServiceTerminateReasonGeneralError:
            return @"general-error";
        case TLPeerConnectionServiceTerminateReasonGone:
            return @"gone";
        case TLPeerConnectionServiceTerminateReasonRevoked:
            return @"revoked";
        case TLPeerConnectionServiceTerminateReasonSuccess:
            return @"success";
        case TLPeerConnectionServiceTerminateReasonTimeout:
            return @"expired";
        case TLPeerConnectionServiceTerminateReasonNotAuthorized:
            return @"not-authorized";
        case TLPeerConnectionServiceTerminateReasonTransferDone:
            return @"transfer-done";
        case TLPeerConnectionServiceTerminateReasonSchedule:
            return @"schedule";
        case TLPeerConnectionServiceTerminateReasonMerge:
            return @"merge";
        case TLPeerConnectionServiceTerminateReasonUnknown:
            return @"unknown";
        default:
            return @"unknown";
    }
}

+ (TLPeerConnectionServiceTerminateReason)stringToTerminateReason:(nonnull NSString *)reason {
    
    if ([reason isEqualToString:@"busy"]) {
        return TLPeerConnectionServiceTerminateReasonBusy;
    }
    if ([reason isEqualToString:@"cancel"]) {
        return TLPeerConnectionServiceTerminateReasonCancel;
    }
    if ([reason isEqualToString:@"connectivity-error"]) {
        return TLPeerConnectionServiceTerminateReasonConnectivityError;
    }
    if ([reason isEqualToString:@"decline"]) {
        return TLPeerConnectionServiceTerminateReasonDecline;
    }
    if ([reason isEqualToString:@"disconnected"]) {
        return TLPeerConnectionServiceTerminateReasonDisconnected;
    }
    if ([reason isEqualToString:@"gone"]) {
        return TLPeerConnectionServiceTerminateReasonGone;
    }
    if ([reason isEqualToString:@"general-error"]) {
        return TLPeerConnectionServiceTerminateReasonGeneralError;
    }
    if ([reason isEqualToString:@"revoked"]) {
        return TLPeerConnectionServiceTerminateReasonRevoked;
    }
    if ([reason isEqualToString:@"success"]) {
        return TLPeerConnectionServiceTerminateReasonSuccess;
    }
    if ([reason isEqualToString:@"expired"]) {
        return TLPeerConnectionServiceTerminateReasonTimeout;
    }
    if ([reason isEqualToString:@"not-authorized"]) {
        return TLPeerConnectionServiceTerminateReasonNotAuthorized;
    }
    if ([reason isEqualToString:@"transfer-done"]) {
        return TLPeerConnectionServiceTerminateReasonTransferDone;
    }
    if ([reason isEqualToString:@"schedule"]) {
        return TLPeerConnectionServiceTerminateReasonSchedule;
    }
    if ([reason isEqualToString:@"merge"]) {
        return TLPeerConnectionServiceTerminateReasonMerge;
    }
    return TLPeerConnectionServiceTerminateReasonUnknown;
}

+ (TLPeerConnectionServiceTerminateReason)toTerminateReason:(TLBaseServiceErrorCode)errorCode {
    /**
     * Errors returned by createIncomingPeerConnection():
     * - ITEM_NOT_FOUND: P2P session not found
     * - NO_PUBLIC_KEY: No session key pair to decrypt the encrypted IQ, twincode.isEncrypted() && !peer.isEncrypted()
     * - NOT_ENCRYPTED: the P2P session must be encrypted and we received an unencrypted SDP
     *
     * Errors returned by onSessionAccept(), onSessionUpdate(), onTransportInfo():
     * - ITEM_NOT_FOUND: P2P session not found
     * - BAD_REQUEST: Decrypted SDP is empty or null.
     * - NO_PRIVATE_KEY: No session key pair to decrypt the encrypted IQ
     * - BAD_SIGNATURE: Invalid session ID in encrypted payload
     * - NO_SECRET_KEY: Used secret key is not known to decrypt
     * - DECRYPT_ERROR: Decrypt error
     * - BAD_ENCRYPTION_FORMAT: exception raised when deserializing the decrypted data.
     * - LIBRARY_ERROR: Internal exception raised.
     */

    switch (errorCode) {
        case TLBaseServiceErrorCodeSuccess:
            return TLPeerConnectionServiceTerminateReasonSuccess;

        case TLBaseServiceErrorCodeInvalidPublicKey:
        case TLBaseServiceErrorCodeInvalidPrivateKey:
        case TLBaseServiceErrorCodeNoPrivateKey:
            return TLPeerConnectionServiceTerminateReasonNoPrivateKey;

        case TLBaseServiceErrorCodeNoPublicKey:
            return TLPeerConnectionServiceTerminateReasonNoPublicKey;

        case TLBaseServiceErrorCodeNoSecretKey:
            return TLPeerConnectionServiceTerminateReasonNoSecretKey;

        case TLBaseServiceErrorCodeNotEncrypted:
            return TLPeerConnectionServiceTerminateReasonNotEncrypted;

        case TLBaseServiceErrorCodeEncryptError:
            return TLPeerConnectionServiceTerminateReasonEncryptError;

        case TLBaseServiceErrorCodeBadSignature:
        case TLBaseServiceErrorCodeBadSignatureFormat:
        case TLBaseServiceErrorCodeBadSignatureMissingAttribute:
        case TLBaseServiceErrorCodeBadSignatureNotSignedAttribute:
        case TLBaseServiceErrorCodeBadEncryptionFormat:
        case TLBaseServiceErrorCodeDecryptError:
            return TLPeerConnectionServiceTerminateReasonDecryptError;

        default:
            return TLPeerConnectionServiceTerminateReasonUnknown;
    }
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    if (self) {
        _peerConnections = [[NSMutableDictionary alloc] init];
        const char *executorQueueName = "peerConnectionExecutorQueue";
        _executorQueue = dispatch_queue_create(executorQueueName, DISPATCH_QUEUE_SERIAL);
        _executorQueueTag = &_executorQueueTag;
        dispatch_queue_set_specific(_executorQueue, _executorQueueTag, _executorQueueTag, NULL);

        const char *cleaningQueueName = "peerConnectionCleaningQueue";
        _cleaningQueue = dispatch_queue_create(cleaningQueueName, DISPATCH_QUEUE_SERIAL);
        _peerCallService = twinlife.peerCallService;
        _cryptoService = twinlife.cryptoService;
        _closeCount = 0;
        _closeDoneCount = 0;
        _closeQueuedCount = 0;
        _dataFactoryCreateCount = 0;
        _dataFactoryDeleteCount = 0;
        _mediaFactoryCreateCount = 0;
        _mediaFactoryDeleteCount = 0;
        
        _videoFrameWidth = MAX_VIDEO_WIDTH;
        _videoFrameHeight = MAX_VIDEO_HEIGHT;
        _videoFrameRate = MAX_VIDEO_FRAME_RATE;
        _usingFrontCamera = YES;
        
        RTC_OBJC_TYPE(RTCConfiguration) *configuration = [[RTC_OBJC_TYPE(RTCConfiguration) alloc] init];
        configuration.sdpSemantics = RTCSdpSemanticsUnifiedPlan;
        configuration.disableLinkLocalNetworks = YES;
        configuration.enableImplicitRollback = YES;
        configuration.continualGatheringPolicy = RTCContinualGatheringPolicyGatherContinually;
        configuration.bundlePolicy = RTCBundlePolicyMaxBundle;
        
        // Disable SRTP_AES128_CM_SHA1_32 and enable SRTP_AEAD_AES_256_GCM.
        configuration.cryptoOptions = [[RTC_OBJC_TYPE(RTCCryptoOptions) alloc] initWithSrtpEnableGcmCryptoSuites:true srtpEnableAes128Sha1_32CryptoCipher:false srtpEnableEncryptedRtpHeaderExtensions:false sframeRequireFrameEncryption:false];
        
        _peerConnectionConfiguration = configuration;
        
        NSMutableDictionary<NSString *, NSString *> *fieldTrials = [[NSMutableDictionary alloc] init];
        [fieldTrials setObject:kRTCFieldTrialEnabledValue forKey:kRTCFieldTrialUseNWPathMonitor];
        RTCInitFieldTrialDictionary(fieldTrials);
    }
    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    if ([delegate conformsToProtocol:@protocol(TLPeerConnectionServiceDelegate)]) {
        [super addDelegate:delegate];
    }
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLPeerConnectionServiceConfiguration *peerConnectionServiceConfiguration = [[TLPeerConnectionServiceConfiguration alloc] init];
    TLPeerConnectionServiceConfiguration *serviceConfiguration = (TLPeerConnectionServiceConfiguration *)baseServiceConfiguration;
    peerConnectionServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    peerConnectionServiceConfiguration.enableAudioVideo = serviceConfiguration.enableAudioVideo;
    peerConnectionServiceConfiguration.acceptIncomingCalls = serviceConfiguration.acceptIncomingCalls;
    peerConnectionServiceConfiguration.turnServers = [[NSMutableArray alloc] initWithCapacity:1];
    self.configured = YES;
    self.serviceConfiguration = peerConnectionServiceConfiguration;
    self.serviceOn = peerConnectionServiceConfiguration.isServiceOn;
    [self.twinlife getPeerCallService].peerSignalingDelegate = self;
    RTCSetMinDebugLogLevel(RTCLoggingSeverityNone);
}

- (void)onConfigure {
    DDLogVerbose(@"%@: onConfigure", LOG_TAG);
    
    [super onConfigure];
    
    self.configuration = [[self.twinlife getManagementService] configuration];
    
    if (self.configuration.maxSentFrameSize < self.videoFrameWidth * self.videoFrameHeight) {
        if (self.configuration.maxSentFrameSize < 240 * 160) {
            // QQVGA: 160 x 120
            self.videoFrameWidth = 160;
            self.videoFrameHeight = 120;
        } else if (self.configuration.maxSentFrameSize < 320 * 240) {
            // HQVGA: 240 x 160
            self.videoFrameWidth = 240;
            self.videoFrameHeight = 160;
        } else if (self.configuration.maxSentFrameSize < 640 * 480) {
            // QVGA: 320 x 240
            self.videoFrameWidth = 320;
            self.videoFrameHeight = 240;
        } else if (self.configuration.maxSentFrameSize < 1280 * 720) {
            // VGA: 640 x 480
            self.videoFrameWidth = 640;
            self.videoFrameHeight = 480;
        }
    }
    
    if (self.configuration.maxSentFrameRate < self.videoFrameRate) {
        if (self.configuration.maxSentFrameRate < MIN_VIDEO_FRAME_RATE) {
            self.videoFrameRate = MIN_VIDEO_FRAME_RATE;
        } else {
            self.videoFrameRate = self.configuration.maxSentFrameRate;
        }
    }
}

- (void)onUpdateConfigurationWithConfiguration:(TLBaseServiceImplConfiguration *)configuration {
    DDLogVerbose(@"%@ onUpdateConfigurationWithConfiguration: %@", LOG_TAG, configuration);
    
    NSMutableArray *iceServers = [[NSMutableArray alloc] initWithCapacity:configuration.turnServers.count];
    for (TLTurnServer *turnServer in configuration.turnServers) {
        RTCTlsCertPolicy policy = [turnServer.url hasPrefix:@"turns"] ? RTCTlsCertPolicySecure : RTCTlsCertPolicyInsecureNoCheck;
        
        NSMutableArray *urls = [[NSMutableArray alloc] initWithCapacity:1];
        [urls addObject:turnServer.url];
        [iceServers addObject:[[RTC_OBJC_TYPE(RTCIceServer) alloc] initWithURLStrings:urls username:turnServer.username credential:turnServer.password tlsCertPolicy:policy]];
    }
    self.iceServers = iceServers;
    self.hostnames = configuration.hostnames;
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
    long count;
    @synchronized (self) {
        count = self.peerConnections.count;
        if (count == 0) {
            return;
        }
        
        // Terminate the active P2P connection to make sure we don't receive anything while we suspend.
        // We keep the P2P connection in peerConnections so that we trigger the onTerminatePeerConnection
        // the final cleanup will be handled there.
        for (NSUUID *peerConnectionId in self.peerConnections) {
            TLPeerConnection *peerConnection = self.peerConnections[peerConnectionId];
            
            if (peerConnection) {
                [peerConnection onTwinlifeSuspend];
            }
        }
    }
    
    DDLogVerbose(@"%@ suspending with %ld P2P active sessions", LOG_TAG, count);
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    [super onTwinlifeOnline];
    
    RTC_OBJC_TYPE(RTCConfiguration) *configuration = [[RTC_OBJC_TYPE(RTCConfiguration) alloc] init];
    configuration.sdpSemantics = RTCSdpSemanticsUnifiedPlan;
    configuration.disableLinkLocalNetworks = YES;
    configuration.enableImplicitRollback = YES;
    configuration.continualGatheringPolicy = RTCContinualGatheringPolicyGatherContinually;
    configuration.bundlePolicy = RTCBundlePolicyMaxBundle;

    // Prune relay ports to drop duplicates and keep highest priority.
    configuration.turnPortPrunePolicy = RTCPortPrunePolicyPruneBasedOnPriority;
    configuration.iceServers = self.iceServers;
    configuration.hostnames = self.hostnames;
    
    // Disable SRTP_AES128_CM_SHA1_32 and enable SRTP_AEAD_AES_256_GCM.
    configuration.cryptoOptions = [[RTC_OBJC_TYPE(RTCCryptoOptions) alloc] initWithSrtpEnableGcmCryptoSuites:true srtpEnableAes128Sha1_32CryptoCipher:false srtpEnableEncryptedRtpHeaderExtensions:false sframeRequireFrameEncryption:false];
    
    self.peerConnectionConfiguration = configuration;
}

#pragma mark - PeerConnectionService

- (long)sessionCount {
    
    long count;
    @synchronized (self) {
        count = self.peerConnections.count;
    }

    DDLogVerbose(@"%@ sessionCount %ld", LOG_TAG, count);
    return count;
}

- (void)triggerSessionPing {
    DDLogVerbose(@"%@ triggerSessionPing", LOG_TAG);
    
    // Process reconnection to the server (if necessary).
    @synchronized (self) {
        for (NSUUID *peerConnectionId in self.peerConnections) {
            TLPeerConnection *peerConnection = self.peerConnections[peerConnectionId];
            
            if (peerConnection) {
                [peerConnection sessionPing];
            }
        }
    }
}

- (nonnull NSString *)getP2PDiagnostics {
    
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];
    [result appendString:@"P2Psessions:"];
    @synchronized (self) {
        [result appendFormat:@" %ld", self.peerConnections.count];
    }
    [result appendFormat:@" %d %d %d [%d-%d %d-%d]\n", atomic_load(&_closeQueuedCount), atomic_load(&_closeCount), atomic_load(&_closeDoneCount), atomic_load(&_dataFactoryCreateCount), atomic_load(&_dataFactoryDeleteCount), atomic_load(&_mediaFactoryCreateCount), atomic_load(&_mediaFactoryDeleteCount)];
    return result;
}

- (BOOL)isAudioVideoEnabled {
    DDLogVerbose(@"%@ isAudioVideoEnabled", LOG_TAG);
    
    TLPeerConnectionServiceConfiguration *config = (TLPeerConnectionServiceConfiguration *)self.serviceConfiguration;
    return config.enableAudioVideo;
}

- (TLBaseServiceErrorCode)listenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId delegate:(nonnull id<TLPeerConnectionDelegate>)delegate {
    DDLogVerbose(@"%@ listenWithPeerConnectionId: %@ delegate: %@", LOG_TAG, peerConnectionId, delegate);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
        if (peerConnection) {
            peerConnection.delegate = delegate;
            return TLBaseServiceErrorCodeSuccess;
        } else {
            return TLBaseServiceErrorCodeItemNotFound;
        }
    }
}

- (void)createIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createIncomingPeerConnectionWithPeerConnectionId: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerConnectionId, offer, offerToReceive);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
        return;
    }
    
    TLBaseServiceErrorCode errorCode = [self createSecuredIncomingPeerConnectionWithPeerConnection:peerConnection sessionKeyPair:nil offer:offer offerToReceive:offerToReceive dataChannelDelegate:dataChannelDelegate delegate:delegate withBlock:block];
    
    // If we failed to handle the incoming P2P connection, terminate the P2P with a specific terminate reason to inform the peer.
    if (errorCode != TLBaseServiceErrorCodeQueued) {
        [peerConnection terminatePeerConnectionWithTerminateReason:[TLPeerConnectionService toTerminateReason:errorCode] notifyPeer:YES];
        block(errorCode, nil);
    }
}

- (void)createIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId subject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createIncomingPeerConnectionWithPeerConnectionId: %@ subject: %@ peerTwincodeOutbound: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerConnectionId, subject, peerTwincodeOutbound, offer, offerToReceive);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
        return;
    }

    TLBaseServiceErrorCode errorCode;
    TLTwincodeOutbound *twincodeOutbound = [subject twincodeOutbound];
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        errorCode = TLBaseServiceErrorCodeBadRequest;
    } else {
        id<TLSessionKeyPair> sessionKeyPair;
        errorCode = [self.cryptoService createKeyPairWithSessionId:peerConnectionId twincodeOutbound:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound keyPair:&sessionKeyPair strict:NO];
        TLPeerConnectionServiceSdpEncryptionStatus sdpEncryptionStatus = [peerConnection sdpEncryptionStatus];
        if ([twincodeOutbound isEncrypted] && [peerTwincodeOutbound isEncrypted] && errorCode != TLBaseServiceErrorCodeSuccess) {
            [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint DECRYPT_ERROR_1], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithTwincodeOutbound:peerTwincodeOutbound], [TLAssertValue initWithErrorCode:errorCode], nil];
            errorCode = errorCode;
        } else if (errorCode != TLBaseServiceErrorCodeSuccess && sdpEncryptionStatus != TLPeerConnectionServiceSdpEncryptionStatusNone) {
            [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint DECRYPT_ERROR_2], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithTwincodeOutbound:peerTwincodeOutbound], [TLAssertValue initWithErrorCode:errorCode], [TLAssertValue initWithSdpEncryptionStatus:sdpEncryptionStatus], nil];
            errorCode = [twincodeOutbound isEncrypted] ? TLBaseServiceErrorCodeNoPublicKey : TLBaseServiceErrorCodeNoPrivateKey;
        } else if (errorCode == TLBaseServiceErrorCodeSuccess && sessionKeyPair && sdpEncryptionStatus == TLPeerConnectionServiceSdpEncryptionStatusNone) {
            errorCode = TLBaseServiceErrorCodeNotEncrypted;
        } else {
            errorCode = [self createSecuredIncomingPeerConnectionWithPeerConnection:peerConnection sessionKeyPair:sessionKeyPair offer:offer offerToReceive:offerToReceive dataChannelDelegate:dataChannelDelegate delegate:delegate withBlock:block];
        }
    }

    // If we failed to handle the incoming P2P connection, terminate the P2P with a specific terminate reason to inform the peer.
    if (errorCode != TLBaseServiceErrorCodeQueued) {
        [peerConnection terminatePeerConnectionWithTerminateReason:[TLPeerConnectionService toTerminateReason:errorCode] notifyPeer:YES];
        block(errorCode, nil);
    }
}

- (TLBaseServiceErrorCode)createSecuredIncomingPeerConnectionWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sessionKeyPair:(nullable id<TLSessionKeyPair>)sessionKeyPair offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createSecuredIncomingPeerConnectionWithPeerConnection: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerConnection, offer, offerToReceive);

    peerConnection.offer = offer;
    peerConnection.offerToReceive = offerToReceive;
    RTC_OBJC_TYPE(RTCSessionDescription) *sessionDescription = nil;
    
    if (sessionKeyPair) {
        NSArray<TLSdp *> *sdpList = [peerConnection configureSessionKey:sessionKeyPair];
        if (sdpList) {
            for (TLSdp *sdp in sdpList) {
                TLBaseServiceErrorCode errorCode;
                TLSdp *decryptedSdp = [self decryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
                if (!decryptedSdp) {
                    return errorCode;
                }
                NSString *sdpDescription = [decryptedSdp sdp];
                if (!sdpDescription) {
                    return TLBaseServiceErrorCodeBadRequest;
                }
                if (!sessionDescription) {
                    sessionDescription = [[RTC_OBJC_TYPE(RTCSessionDescription) alloc] initWithType:RTCSdpTypeOffer sdp:sdpDescription];
                } else {
                    NSArray<TLTransportCandidate *> *candidates = [decryptedSdp candidates];
                    if (!candidates) {
                        return TLBaseServiceErrorCodeBadRequest;
                    }
                    [peerConnection addIceCandidates:candidates];
                }
            }
        }
    } else if ([peerConnection sdpEncryptionStatus] != TLPeerConnectionServiceSdpEncryptionStatusNone) {
        return TLBaseServiceErrorCodeNoPrivateKey;
    }

    [peerConnection createIncomingPeerConnectionWithConfiguration:self.peerConnectionConfiguration sessionDescription:sessionDescription dataChannelDelegate:dataChannelDelegate delegate:delegate withBlock:block];
    return TLBaseServiceErrorCodeQueued;
}

- (void)createOutgoingPeerConnectionWithPeerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createOutgoingPeerConnectionWithPeerId: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerId, offer, offerToReceive);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSUUID *sessionId = [NSUUID UUID];
    [self createSecuredOutgoingPeerConnectionWithSessionId:sessionId sessionKeyPair:nil peerId:peerId offer:offer offerToReceive:offerToReceive notificationContent:notificationContent dataChannelDelegate:dataChannelDelegate delegate:delegate withBlock:block];
}

- (void)createOutgoingPeerConnectionWithSubject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createOutgoingPeerConnectionWithSubject: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerTwincodeOutbound, offer, offerToReceive);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    TLTwincodeOutbound *twincodeOutbound = [subject twincodeOutbound];
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }

    NSString *peerId = [[self.twinlife getTwincodeOutboundService] getPeerId:peerTwincodeOutbound.uuid twincodeOutboundId:twincodeOutbound.uuid];
    NSUUID *sessionId = [NSUUID UUID];
    id<TLSessionKeyPair> sessionKeyPair;
    TLBaseServiceErrorCode errorCode = [self.cryptoService createKeyPairWithSessionId:sessionId twincodeOutbound:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound keyPair:&sessionKeyPair strict:YES];
    if ([twincodeOutbound isEncrypted] && [peerTwincodeOutbound isEncrypted] && errorCode != TLBaseServiceErrorCodeSuccess) {
        [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint ENCRYPT_ERROR], [TLAssertValue initWithSubject:subject], [TLAssertValue initWithTwincodeOutbound:peerTwincodeOutbound], [TLAssertValue initWithErrorCode:errorCode], nil];

        block(errorCode, nil);
        return;
    }

    [self createSecuredOutgoingPeerConnectionWithSessionId:sessionId sessionKeyPair:sessionKeyPair peerId:peerId offer:offer offerToReceive:offerToReceive notificationContent:notificationContent dataChannelDelegate:dataChannelDelegate delegate:delegate withBlock:block];
}

- (void)createSecuredOutgoingPeerConnectionWithSessionId:(nonnull NSUUID *)sessionId sessionKeyPair:(nullable id<TLSessionKeyPair>)sessionKeyPair peerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createSecuredOutgoingPeerConnectionWithSessionId: %@ offer: %@ offerToReceive: %@", LOG_TAG, peerId, offer, offerToReceive);

    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = [[TLPeerConnection alloc] initWithPeerConnectionService:self sessionId:sessionId sessionKeyPair:sessionKeyPair peerId:peerId offer:offer offerToReceive:offerToReceive notificationContent:notificationContent configuration:self.configuration delegate:delegate];
        self.peerConnections[sessionId] = peerConnection;
        if (!self.networkLock) {
            self.networkLock = [self.jobService allocateNetworkLock];
        }
    }
    
    [peerConnection createOutgoingPeerConnectionWithConfiguration:self.peerConnectionConfiguration dataChannelDelegate:dataChannelDelegate withBlock:block];
}

- (void)initSourcesWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId audioOn:(BOOL)audioOn videoOn:(BOOL)videoOn {
    DDLogVerbose(@"%@ initSourcesWithPeerConnectionId: %@ audioOn: %@ videoOn: %@", LOG_TAG, peerConnectionId, audioOn ? @"YES" : @"NO", videoOn ? @"YES" : @"NO");
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        [self onTerminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
        return;
    }
    
    [peerConnection initSourcesWithAudioOn:audioOn videoOn:videoOn];
}

- (void)terminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ terminatePeerConnectionWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
        if (!peerConnection) {
            return;
        }
        [self.peerConnections removeObjectForKey:peerConnectionId];
        if (self.peerConnections.count == 0 && self.networkLock) {
            [self.networkLock releaseLock];
            self.networkLock = nil;
        }
    }
    
    [peerConnection terminatePeerConnectionWithTerminateReason:terminateReason notifyPeer:YES];
}

- (BOOL)isTerminatedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ isTerminatedWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    @synchronized (self) {
        return self.peerConnections[peerConnectionId] == nil;
    }
}

- (TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatusWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ sdpEncryptionStatusWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    @synchronized (self) {
        TLPeerConnection *peerConnection = self.peerConnections[peerConnectionId];
        
        return peerConnection ? [peerConnection sdpEncryptionStatus] : TLPeerConnectionServiceSdpEncryptionStatusNone;
    }
}

- (nullable TLOffer *)getPeerOfferWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ getPeerOfferWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (peerConnection) {
        return peerConnection.peerOffer;
    }
    return nil;
}

- (nullable TLOfferToReceive *)getPeerOfferToReceiveWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ getPeerOfferToReceiveWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (peerConnection) {
        return peerConnection.peerOfferToReceive;
    }
    return nil;
}

- (nullable NSString *)getPeerIdWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ getPeerIdWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (peerConnection) {
        return peerConnection.peerId;
    }
    return nil;
}

- (void)setAudioDirectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId direction:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setAudioDirectionWithPeerConnectionId: %@ direction: %ld", LOG_TAG, peerConnectionId, (long)direction);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        return;
    }
    
    [peerConnection setAudioDirection:direction];
}

- (void)setVideoDirectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId direction:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setVideoDirectionWithPeerConnectionId: %@ direction: %ld", LOG_TAG, peerConnectionId, (long)direction);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        return;
    }
    
    [peerConnection setVideoDirection:direction];
}

- (void)switchCameraWithFront:(BOOL)front withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, BOOL isFronCamera))block {
    DDLogVerbose(@"%@ switchCameraWithFront: %d", LOG_TAG, front);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, NO);
        return;
    }

    dispatch_async(self.executorQueue, ^{
        [self switchCameraInternalWithFront:front withBlock:block];
    });
}

- (void)sendMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType data:(nonnull NSMutableData *)data {
    DDLogVerbose(@"%@ sendMessageWithPeerConnectionId: %@ statType: %u data: %@ ", LOG_TAG, peerConnectionId, statType, data);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        return;
    }
    
    [peerConnection sendMessageWithData:data statType:statType];
}

- (void)sendPacketWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType iq:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ sendPacketWithPeerConnectionId: %@ statType: %u iq: %@", LOG_TAG, peerConnectionId, statType, iq);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        return;
    }
    
    [peerConnection sendPacketWithIQ:iq statType:statType];
}

- (void)incrementStatWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ incrementStatWithPeerConnectionId: %@ statType: %u", LOG_TAG, peerConnectionId, statType);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (!peerConnection) {
        return;
    }
    
    [peerConnection incrementStatWithStatType:statType];
}

- (void)sendCallQualityWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId quality:(int)quality {
    DDLogVerbose(@"%@ sendCallQualityWithPeerConnectionId: %@ quality: %d", LOG_TAG, peerConnectionId, quality);
    
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSMutableString *qualityReport = [[NSMutableString alloc] initWithCapacity:64];
    
    [qualityReport appendFormat:@"%d", quality];
    [attributes setObject:peerConnectionId.UUIDString forKey:@"p2pSessionId"];
    [attributes setObject:qualityReport forKey:@"quality"];
    [[self.twinlife getManagementService] logEventWithEventId:EVENT_ID_REPORT_QUALITY attributes:attributes flush:YES];
}

#pragma mark - TLPeerSignalingDelegate ()

/// Called when a session-initiate IQ is received.
///
/// @param sessionId the P2P session id.
/// @param from the target identification string.
/// @param to the source/originator identification string.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max received frame size.
/// @param maxReceivedFrameRate the max received frame rate.
/// @return SUCCESS, NO_PERMISSION, ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionInitiateWithSessionId:(nonnull NSUUID *)sessionId from:(nonnull NSString *)from to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate {
    DDLogVerbose(@"%@ onSessionInitiateWithSessionId: %@ sdp: %@ offer: %@ offerToReceive: %@ maxReceivedFrameSize: %d maxReceivedFrameRate: %d", LOG_TAG, sessionId, sdp, offer, offerToReceive, maxReceivedFrameSize, maxReceivedFrameRate);

    TLPeerConnectionServiceConfiguration* peerConnectionServiceConfiguration = (TLPeerConnectionServiceConfiguration *) self.serviceConfiguration;
    if (!peerConnectionServiceConfiguration.acceptIncomingCalls) {
        return TLBaseServiceErrorCodeNoPermission;
    }
    
    // If we are suspended or going to suspend, we must not accept an incoming P2P connection.
    // It is best to ignore this and don't send any "gone" or "busy".
    if ([self.twinlife status] != TLTwinlifeStatusStarted) {
        return TLBaseServiceErrorCodeTwinlifeOffline;
    }
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        if (self.peerConnections[sessionId]) {
            return TLBaseServiceErrorCodeSuccess;
        }
        // Note: at this step, if the SDP is encrypted, we cannot decrypt it until createIncomingPeerConnection() is called.
        peerConnection = [[TLPeerConnection alloc] initWithPeerConnectionService:self sessionId:sessionId peerId:from offer:offer offerToReceive:offerToReceive configuration:self.configuration sdp:sdp];
        self.peerConnections[sessionId] = peerConnection;
        if (!self.networkLock) {
            self.networkLock = [self.jobService allocateNetworkLock];
        }
    }
    
    if (offerToReceive.video) {
        [self setPeerConstraintsWithMaxReceivedFrameSize:maxReceivedFrameSize maxReceivedFrameRate:maxReceivedFrameRate];
    }
    
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onIncomingPeerConnectionWithPeerConnectionId:peerId:offer:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerConnectionServiceDelegate>)delegate onIncomingPeerConnectionWithPeerConnectionId:sessionId peerId:from offer:offer];
            });
        }
    }
    
    return TLBaseServiceErrorCodeSuccess;
}

/// Called when a session-accept IQ is received.
///
/// @param sessionId the P2P session id.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max received frame size.
/// @param maxReceivedFrameRate the max received frame rate.
/// @return SUCCESS, NO_PERMISSION, ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionAcceptWithSessionId:(nonnull NSUUID *)sessionId sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate {
    DDLogVerbose(@"%@ onSessionAcceptWithSessionId: %@ sdp: %@ offer: %@ offerToReceive: %@ maxReceivedFrameSize: %d maxReceivedFrameRate: %d", LOG_TAG, sessionId, sdp, offer, offerToReceive, maxReceivedFrameSize, maxReceivedFrameRate);

    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[sessionId];
        if (!peerConnection) {
            return TLBaseServiceErrorCodeItemNotFound;
        }
        peerConnection.peerOffer = offer;
    }

    TLBaseServiceErrorCode errorCode;
    sdp = [self decryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        return errorCode;
    }

    NSString *sdpContent = [sdp sdp];
    if (!sdpContent) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    if (offerToReceive.video) {
        [self setPeerConstraintsWithMaxReceivedFrameSize:maxReceivedFrameSize maxReceivedFrameRate:maxReceivedFrameRate];
    }
    [peerConnection acceptRemoteDescription:[[RTC_OBJC_TYPE(RTCSessionDescription) alloc] initWithType:RTCSdpTypeAnswer sdp:sdpContent]];
    
    return TLBaseServiceErrorCodeSuccess;
}

/// Called when a session-update IQ is received.
///
/// @param sessionId the P2P session id.
/// @param updateType whether this is an offer or an answer.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @return SUCCESS or ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionUpdateWithSessionId:(nonnull NSUUID *)sessionId updateType:(RTCSdpType)updateType sdp:(nonnull TLSdp *)sdp {
    DDLogVerbose(@"%@ onSessionUpdateWithSessionId: %@ type: %d sdp: %@", LOG_TAG, sessionId, (int)updateType, sdp);

    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[sessionId];
    }
    if (!peerConnection) {
        // If we are suspended or going to suspend don't send a termination status if we don't recognize the IQ.
        if ([self.twinlife status] == TLTwinlifeStatusStarted) {
            return TLBaseServiceErrorCodeItemNotFound;
        }
        return TLBaseServiceErrorCodeSuccess;
    }

    TLBaseServiceErrorCode errorCode;
    sdp = [self decryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        return errorCode;
    }

    NSString *sdpContent = [sdp sdp];
    if (!sdpContent) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    [peerConnection updateRemoteDescription:[[RTC_OBJC_TYPE(RTCSessionDescription) alloc] initWithType:updateType sdp:sdpContent]];
    
    return TLBaseServiceErrorCodeSuccess;
}

/// Called when a transport-info IQ is received with a list of candidates.
///
/// @param sessionId the P2P session id.
/// @param sdp the list of candidates.
/// @return SUCCESS or ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onTransportInfoWithSessionId:(nonnull NSUUID *)sessionId sdp:(nonnull TLSdp *)sdp {
    DDLogVerbose(@"%@ onTransportInfoWithSessionId: %@ sdp: %@", LOG_TAG, sessionId, sdp);
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[sessionId];
    }
    if (!peerConnection) {
        // If we are suspended or going to suspend don't send a termination status if we don't recognize the IQ.
        // It is best to let the sender retry later (the "gone" will set a high retry delay).
        if ([self.twinlife status] == TLTwinlifeStatusStarted) {
            return TLBaseServiceErrorCodeItemNotFound;
        }
        return TLBaseServiceErrorCodeSuccess;
    }
    
    // If the SDP is encrypted, we must queue it until we know the session key pair.
    if ([sdp isEncrypted] && [peerConnection queueWithSdp:sdp]) {
        return TLBaseServiceErrorCodeSuccess;
    }
    
    TLBaseServiceErrorCode errorCode;
    sdp = [self decryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        return errorCode;
    }
    
    NSArray<TLTransportCandidate *> *candidates = [sdp candidates];
    if (!candidates) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    [peerConnection addIceCandidates:candidates];
    
    return TLBaseServiceErrorCodeSuccess;
}

/// Called when a session-terminate IQ is received for the given P2P session.
///
/// @param sessionId the P2P session id.
/// @param reason the terminate reason.
- (void)onSessionTerminateWithSessionId:(nonnull NSUUID *)sessionId reason:(TLPeerConnectionServiceTerminateReason)reason {
    DDLogVerbose(@"%@ onSessionTerminateWithSessionId: %@ reason: %d", LOG_TAG, sessionId, reason);
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[sessionId];
    }
    if (peerConnection) {
        [peerConnection terminatePeerConnectionWithTerminateReason:reason notifyPeer:NO];
    }
}

- (void)onDeviceRingingWithSessionId:(nonnull NSUUID *)sessionId {
    DDLogVerbose(@"%@ onDeviceRingingWithSessionId: %@", LOG_TAG, sessionId);
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[sessionId];
    }
    if (peerConnection) {
        for (id<TLBaseServiceDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onDeviceRinging:)]) {
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [(id<TLPeerConnectionServiceDelegate>)delegate onDeviceRinging:sessionId];
                });
            }
        }
    }
}


#pragma mark - TLPeerConnectionService ()

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state {
    DDLogVerbose(@"%@ onChangeConnectionStateWithPeerConnectionId: %@ state: %d", LOG_TAG, peerConnectionId, state);
    
}

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ onTerminatePeerConnectionWithPeerConnection: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
    
    @synchronized (self) {
        [self.peerConnections removeObjectForKey:peerConnectionId];
        if (self.peerConnections.count == 0 && self.networkLock) {
            [self.networkLock releaseLock];
            self.networkLock = nil;
        }
    }
    
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTerminatePeerConnectionWithPeerConnectionId:terminateReason:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerConnectionServiceDelegate>)delegate onTerminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
            });
        }
    }
}

#pragma mark - Internal methods ()

- (BOOL)isExecutorQueue {
    
    return dispatch_get_specific(self.executorQueueTag) != nil;
}

- (nonnull RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)getPeerConnectionFactoryWithMedia:(BOOL)withMedia {
    DDLogVerbose(@"%@: getPeerConnectionFactoryWithMedia: %d", LOG_TAG, withMedia);

    if (withMedia && [self isAudioVideoEnabled]) {
        @synchronized (self) {
            if (self.mediaConnectionFactory) {
                [self.mediaConnectionFactory incrementUseCounter];
                return self.mediaConnectionFactory;
            }
        }
        id<RTC_OBJC_TYPE(RTCVideoEncoderFactory)> videoEncoderFactory = [[RTC_OBJC_TYPE(RTCDefaultVideoEncoderFactory) alloc] init];
        id<RTC_OBJC_TYPE(RTCVideoDecoderFactory)> videoDecoderFactory = [[RTC_OBJC_TYPE(RTCDefaultVideoDecoderFactory) alloc] init];
        RTC_OBJC_TYPE(RTCPeerConnectionFactory) *newFactory = [[RTC_OBJC_TYPE(RTCPeerConnectionFactory) alloc] initWithEncoderFactory:videoEncoderFactory decoderFactory:videoDecoderFactory hostnames:self.peerConnectionConfiguration.hostnames];
        @synchronized (self) {
            if (!self.mediaConnectionFactory) {
                self.mediaConnectionFactory = newFactory;
                atomic_fetch_add(&_mediaFactoryCreateCount, 1);
            }
            [self.mediaConnectionFactory incrementUseCounter];
            return self.mediaConnectionFactory;
        }
    } else {
        @synchronized (self) {
            if (self.dataConnectionFactory) {
                [self.dataConnectionFactory incrementUseCounter];
                return self.dataConnectionFactory;
            }
        }
        RTC_OBJC_TYPE(RTCPeerConnectionFactory) *newFactory = [[RTC_OBJC_TYPE(RTCPeerConnectionFactory) alloc] initWithHostnames:self.peerConnectionConfiguration.hostnames];
        @synchronized (self) {
            if (!self.dataConnectionFactory) {
                self.dataConnectionFactory = newFactory;
                atomic_fetch_add(&_dataFactoryCreateCount, 1);
            }
            [self.dataConnectionFactory incrementUseCounter];
            return self.dataConnectionFactory;
        }
    }
}

- (void)disposeWithPeerConnection:(nullable RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection factory:(nullable RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)factory {
    DDLogVerbose(@"%@: disposeWithPeerConnection: %@ factory: %@", LOG_TAG, peerConnection, factory);
    
    if (peerConnection) {
        atomic_fetch_add(&_closeQueuedCount, 1);
        dispatch_async(self.cleaningQueue, ^{
            atomic_fetch_add(&self->_closeCount, 1);
            [peerConnection close];
            atomic_fetch_add(&self->_closeDoneCount, 1);
        });
    }
    if (factory) {
        dispatch_async(self.cleaningQueue, ^{
            @synchronized (self) {
                [factory decrementUseCounter];
                if (self.mediaConnectionFactory && ![self.mediaConnectionFactory isUsed]) {
                    self.mediaConnectionFactory = nil;
                    atomic_fetch_add(&self->_mediaFactoryDeleteCount, 1);
                }
                if (self.dataConnectionFactory && ![self.dataConnectionFactory isUsed]) {
                    self.dataConnectionFactory = nil;
                    atomic_fetch_add(&self->_dataFactoryDeleteCount, 1);
                }
            }
        });
    }
}

- (nullable RTC_OBJC_TYPE(RTCVideoTrack) *)createVideoTrackWithPeerConnectionFactory:(nonnull RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)peerConnectionFactory {
    DDLogVerbose(@"%@: createVideoTrackWithPeerConnectionFactory", LOG_TAG);

    RTC_OBJC_TYPE(RTCVideoTrack) *videoTrack;
    @synchronized (self) {
        if (self.videoCapturer && self.videoTrack) {
            self.videoConnections++;
            return self.videoTrack;
        }
        
        self.videoSource = [peerConnectionFactory videoSource];
        self.videoCapturer = [[RTC_OBJC_TYPE(RTCCameraVideoCapturer) alloc] initWithDelegate:self.videoSource];
        if (!self.videoCapturer) {
            self.videoSource = nil;
            return nil;
        }
        
        if (![self startCaptureWithBlock:^(TLBaseServiceErrorCode errorCode, BOOL isFrontCamera) {
            
        }]) {
            self.videoSource = nil;
            self.videoCapturer = nil;
            return nil;
        }
        
        self.videoConnections = 1;
        self.videoTrack = [peerConnectionFactory videoTrackWithSource:self.videoSource trackId:[[NSUUID UUID] UUIDString]];
        videoTrack = self.videoTrack;
    }
    
    videoTrack.isEnabled = YES;
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateLocalVideoTrack:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerConnectionServiceDelegate>)delegate onCreateLocalVideoTrack:videoTrack];
            });
        }
    }
    return videoTrack;
}

- (BOOL)startCaptureWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, BOOL isFronCamera))block{
    DDLogVerbose(@"%@: startCaptureWithBlock", LOG_TAG);
    
    AVCaptureDevice *captureDevice;
    AVCaptureDevicePosition position = self.usingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    NSArray<AVCaptureDevice *> *captureDevices = [RTC_OBJC_TYPE(RTCCameraVideoCapturer) captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            captureDevice = device;
        }
    }
    if (!captureDevice) {
        if (captureDevices.count < 1) {
            return NO;
        }
        captureDevice = captureDevices[0];
    }
    NSArray<AVCaptureDeviceFormat *> *formats = [RTC_OBJC_TYPE(RTCCameraVideoCapturer) supportedFormatsForDevice:captureDevice];
    int targetWidth = self.videoFrameWidth;
    int targetHeight = self.videoFrameHeight;
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;
    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == [self.videoCapturer preferredOutputPixelFormat]) {
            selectedFormat = format;
        }
    }
    if (!selectedFormat) {
        return NO;
    }
    Float64 selectedFramerate = 0;
    for (AVFrameRateRange *fpsRange in selectedFormat.videoSupportedFrameRateRanges) {
        selectedFramerate = fmax(selectedFramerate, fpsRange.maxFrameRate);
    }
    if (selectedFramerate >= self.videoFrameRate) {
        selectedFramerate = self.videoFrameRate;
    }
    
    [self.videoCapturer startCaptureWithDevice:captureDevice format:selectedFormat fps:selectedFramerate completionHandler:^(NSError * _Nullable error) {
        dispatch_async([self.twinlife twinlifeQueue], ^{
            TLBaseServiceErrorCode errorCode = TLBaseServiceErrorCodeSuccess;
            
            block(errorCode, self.usingFrontCamera);
        });
    }];
    return YES;
}

- (void)releaseVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack {
    DDLogVerbose(@"%@: releaseVideoTrack", LOG_TAG);
    
    RTC_OBJC_TYPE(RTCCameraVideoCapturer) *videoCapturer;
    @synchronized (self) {
        if (videoTrack != self.videoTrack) {
            return;
        }
        self.videoConnections--;
        if (self.videoConnections > 0) {
            return;
        }
        videoCapturer = self.videoCapturer;
        self.videoTrack = nil;
        self.videoSource = nil;
        self.videoCapturer = nil;
    }
    
    [videoCapturer stopCapture];
    
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onRemoveLocalVideoTrack)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerConnectionServiceDelegate>)delegate onRemoveLocalVideoTrack];
            });
        }
    }
}

- (void)switchCameraInternalWithFront:(BOOL)front withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, BOOL isFronCamera))block {
    DDLogVerbose(@"%@ switchCameraInternalWithFront: %d", LOG_TAG, front);
    
    BOOL oldState = self.usingFrontCamera;
    self.usingFrontCamera = front;
    if (!self.videoCapturer || ![self startCaptureWithBlock:block]) {
        self.usingFrontCamera = oldState;
        dispatch_async([self.twinlife twinlifeQueue], ^{
            block(TLBaseServiceErrorCodeItemNotFound, NO);
        });
    }
}

- (void)setPeerConstraintsWithMaxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate {
    DDLogVerbose(@"%@ setPeerConstraintsWithMaxReceivedFrameSize: %d maxReceivedFrameRate: %d", LOG_TAG, maxReceivedFrameSize, maxReceivedFrameRate);
    
    BOOL update = NO;
    if (maxReceivedFrameSize < self.videoFrameWidth * self.videoFrameHeight) {
        update = YES;
        
        if (maxReceivedFrameSize < 240 * 160) {
            // QQVGA: 160 x 120
            self.videoFrameWidth = 160;
            self.videoFrameHeight = 120;
        } else if (maxReceivedFrameSize < 320 * 240) {
            // HQVGA: 240 x 160
            self.videoFrameWidth = 240;
            self.videoFrameHeight = 160;
        } else if (maxReceivedFrameSize < 640 * 480) {
            // QVGA: 320 x 240
            self.videoFrameWidth = 320;
            self.videoFrameHeight = 240;
        } else if (maxReceivedFrameSize < 1280 * 720) {
            // VGA: 640 x 480
            self.videoFrameWidth = 640;
            self.videoFrameHeight = 480;
        }
    }
    if (maxReceivedFrameRate < self.videoFrameRate) {
        update = YES;
        
        if (maxReceivedFrameRate < MIN_VIDEO_FRAME_RATE) {
            self.videoFrameRate = MIN_VIDEO_FRAME_RATE;
        } else {
            self.videoFrameRate = maxReceivedFrameRate;
        }
    }
    
    if (update && self.videoSource) {
        [self.videoSource adaptOutputFormatToWidth:self.videoFrameWidth height:self.videoFrameHeight fps:self.videoFrameRate];
    }
}

/// Send the session-initiate to start a P2P connection with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param notificationContent information for the push notification.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionInitiateWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent *)notificationContent withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionInitiateWithPeerConnection: %@ sdp: %@", LOG_TAG, peerConnection, sdp);

    TLBaseServiceErrorCode errorCode;
    sdp = [self encryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        block(errorCode, nil);
        return;
    }

    [self.peerCallService sessionInitiateWithSessionId:peerConnection.uuid to:peerConnection.peerId sdp:sdp offer:offer offerToReceive:offerToReceive maxReceivedFrameSize:self.configuration.maxReceivedFrameSize maxReceivedFrameRate:self.configuration.maxReceivedFrameRate notificationContent:notificationContent withBlock:block];
}

/// Send the session-accept to accept an incoming P2P connection with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionAcceptWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionInitiateWithPeerConnection: %@ sdp: %@", LOG_TAG, peerConnection, sdp);

    TLBaseServiceErrorCode errorCode;
    sdp = [self encryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        // Encryption error: we have to terminate and inform the server.
        [self terminateWithPeerConnection:peerConnection errorCode:errorCode];
        block(errorCode, nil);
        return;
    }

    [self.peerCallService sessionAcceptWithSessionId:peerConnection.uuid to:peerConnection.peerId sdp:sdp offer:offer offerToReceive:offerToReceive maxReceivedFrameSize:self.configuration.maxReceivedFrameSize maxReceivedFrameRate:self.configuration.maxReceivedFrameRate withBlock:block];
}

/// Send the session-update to ask for a renegotiation with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the sdp to send.
/// @param type the update type to indicate whether this is an offer or answer.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionUpdateWithPeerConnection:(nonnull TLPeerConnection *)peerConnection type:(RTCSdpType)type sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionUpdateWithPeerConnection: %@ sdp: %@", LOG_TAG, peerConnection, sdp);

    TLBaseServiceErrorCode errorCode;
    sdp = [self encryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        // Encryption error: we have to terminate and inform the server.
        [self terminateWithPeerConnection:peerConnection errorCode:errorCode];
        block(errorCode, nil);
        return;
    }

    [self.peerCallService sessionUpdateWithSessionId:peerConnection.uuid to:peerConnection.peerId type:type sdp:sdp withBlock:block];
}

/// Send the transport info for the P2P session to the peer.
///
/// @param peerConnection the peerConnection.
/// @param candidates the list of candidates.
/// @param block the completion handler executed when the server sends us its response.
- (void)transportInfoWithPeerConnection:(nonnull TLPeerConnection *)peerConnection candidates:(nonnull TLTransportCandidateList *)candidates withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ transportInfoWithPeerConnection: %@", LOG_TAG, peerConnection);
    
    int64_t requestId = [TLTwinlife newRequestId];
    NSNumber *reqId = [NSNumber numberWithLongLong:requestId];
    TLSdp *sdp = [candidates buildSdpWithRequestId:requestId];
    NSData *data = [sdp data];
    
    // The SDP can be empty if all candidates are already sent in a previous SDP transport info.
    if (data.length == 0) {
        block(TLBaseServiceErrorCodeSuccess, reqId);
        return;
    }
    
    TLBaseServiceErrorCode errorCode;
    sdp = [self encryptWithPeerConnection:peerConnection sdp:sdp errorCode:&errorCode];
    if (!sdp) {
        // Encryption error: we have to terminate and inform the server.
        [self terminateWithPeerConnection:peerConnection errorCode:errorCode];
        block(errorCode, reqId);
        return;
    }

    [self.peerCallService transportInfoWithRequestId:requestId sessionId:peerConnection.uuid to:peerConnection.peerId sdp:sdp withBlock:block];
}

- (void)terminateWithPeerConnection:(nonnull TLPeerConnection *)peerConnection errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ terminateWithPeerConnection: %@ errorCode: %d", LOG_TAG, peerConnection, errorCode);

    TLPeerConnectionServiceTerminateReason reason;
    switch (errorCode) {
        case TLBaseServiceErrorCodeNoPrivateKey:
            reason = TLPeerConnectionServiceTerminateReasonNoPrivateKey;
            break;
        case TLBaseServiceErrorCodeInvalidPublicKey:
            reason = TLPeerConnectionServiceTerminateReasonNoPrivateKey;
            break;
        case TLBaseServiceErrorCodeInvalidPrivateKey:
            reason = TLPeerConnectionServiceTerminateReasonNoSecretKey;
            break;
        case TLBaseServiceErrorCodeEncryptError:
            reason = TLPeerConnectionServiceTerminateReasonEncryptError;
            break;
        case TLBaseServiceErrorCodeDecryptError:
            reason = TLPeerConnectionServiceTerminateReasonDecryptError;
            break;
        default:
            reason = TLPeerConnectionServiceTerminateReasonNotAuthorized;
            break;
    }
    [self.peerCallService sessionTerminateWithSessionId:peerConnection.uuid to:peerConnection.peerId reason:reason];
}

- (void)sendDeviceRingingWithPeerConnectionId:(NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ sendDeviceRingingWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
    TLPeerConnection *peerConnection;
    @synchronized (self) {
        peerConnection = self.peerConnections[peerConnectionId];
    }
    if (peerConnection) {
        [peerConnection sendDeviceRinging];
    }
}

- (nullable TLSdp *)decryptWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode {
    DDLogVerbose(@"%@ decryptWithPeerConnection: %@", LOG_TAG, peerConnection);

    id<TLSessionKeyPair> keyPair = peerConnection.keyPair;
    if ([sdp isEncrypted]) {
        [peerConnection incrementStatWithStatType:TLPeerConnectionServiceStatTypeSdpReceiveEncryptedCount];
        if (!keyPair) {
            *errorCode = TLBaseServiceErrorCodeNoPrivateKey;
            return nil;
        }
        return [keyPair decryptWithSdp:sdp errorCode:errorCode];
    } else {
        [peerConnection incrementStatWithStatType:TLPeerConnectionServiceStatTypeSdpReceiveClearCount];
        if (keyPair) {
            *errorCode = TLBaseServiceErrorCodeNotEncrypted;
            return nil;
        }
        *errorCode = TLBaseServiceErrorCodeSuccess;
        return sdp;
    }
}

- (nullable TLSdp *)encryptWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode {
    DDLogVerbose(@"%@ encryptWithPeerConnection: %@", LOG_TAG, peerConnection);

    id<TLSessionKeyPair> keyPair = peerConnection.keyPair;
    if (!keyPair) {
        [peerConnection incrementStatWithStatType:TLPeerConnectionServiceStatTypeSdpSendClearCount];
        *errorCode = TLBaseServiceErrorCodeSuccess;
        return sdp;
    }

    [peerConnection incrementStatWithStatType:TLPeerConnectionServiceStatTypeSdpSendEncryptedCount];
    return [self.cryptoService encryptWithSessionKeyPair:keyPair sdp:sdp errorCode:errorCode];
}

@end
