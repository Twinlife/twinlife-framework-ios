/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <stdlib.h>
#import <libkern/OSAtomic.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <MediaPlayer/MediaPlayer.h>

#import <CocoaLumberjack.h>

#import "TLConversationServiceImpl.h"
#import "TLConversationServiceScheduler.h"
#import "TLRepositoryServiceImpl.h"
#import "TLGroupConversationManager.h"

#import "TLPeerConnectionServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLClearDescriptorImpl.h"
#import "TLConversationServiceIQ.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationProtocol.h"
#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLConversationServiceOperation.h"
#import "TLResetConversationOperation.h"
#import "TLSynchronizeConversationOperation.h"
#import "TLPushCommandOperation.h"
#import "TLPushObjectOperation.h"
#import "TLPushTransientObjectOperation.h"
#import "TLPushFileOperation.h"
#import "TLPushTwincodeOperation.h"
#import "TLGroupInviteOperation.h"
#import "TLGroupJoinOperation.h"
#import "TLGroupLeaveOperation.h"
#import "TLDescriptorImpl.h"
#import "TLObjectDescriptorImpl.h"
#import "TLTransientObjectDescriptorImpl.h"
#import "TLUpdateDescriptorTimestampOperation.h"
#import "TLUpdateGeolocationIQ.h"
#import "TLUpdateTimestampIQ.h"
#import "TLFileDescriptorImpl.h"
#import "TLImageDescriptorImpl.h"
#import "TLAudioDescriptorImpl.h"
#import "TLVideoDescriptorImpl.h"
#import "TLNamedFileDescriptorImpl.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLTwincodeDescriptorImpl.h"
#import "TLGeolocationDescriptorImpl.h"
#import "TLCallDescriptorImpl.h"
#import "TLPushGeolocationOperation.h"
#import "TLUpdateAnnotationsOperation.h"
#import "TLOnUpdateAnnotationsIQ.h"
#import "TLUpdateAnnotationsIQ.h"
#import "TLPushFileIQ.h"
#import "TLPushFileChunkIQ.h"
#import "TLPushThumbnailIQ.h"
#import "TLPushGeolocationIQ.h"
#import "TLPushObjectIQ.h"
#import "TLPushTwincodeIQ.h"
#import "TLResetConversationIQ.h"
#import "TLInviteGroupIQ.h"
#import "TLOnInviteGroupIQ.h"
#import "TLOnPushObjectIQ.h"
#import "TLOnPushFileIQ.h"
#import "TLOnPushFileChunkIQ.h"
#import "TLOnPushTwincodeIQ.h"
#import "TLOnPushGeolocationIQ.h"
#import "TLOnResetConversationIQ.h"
#import "TLSignatureInfoIQ.h"
#import "TLIQ.h"
#import "TLErrorIQ.h"
#import "TLServiceErrorIQ.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLSerializerFactoryImpl.h"
#import "NSUUID+Extensions.h"
#import "TLAttributeNameValue.h"
#import "TLSynchronizeIQ.h"
#import "TLOnSynchronizeIQ.h"
#import "TLSendingFileInfo.h"
#import "TLReceivingFileInfo.h"
#import "TLTwinlifeImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLCryptoServiceImpl.h"
#import "TLJoinGroupIQ.h"
#import "TLOnJoinGroupIQ.h"
#import "TLPushTransientIQ.h"
#import "TLUpdatePermissionsIQ.h"
#import "TLConversationConnection.h"
#import "TLUpdateDescriptorIQ.h"
#import "TLOnUpdateDescriptorIQ.h"
#import "TLUpdateDescriptorOperation.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CONVERSATION_SERVICE_VERSION @"2.20.1" // MUST ALSO UPDATE MAX_MAJOR_VERSION, MAX_MINOR_VERSION_2

#define ENABLE_HARD_RESET (NO)

#define EVENT_ID_SECRET_EXCHANGE     @"twinlife::conversation::secret-exchange"

/*static const int CONVERSATION_SERVICE_MAJOR_VERSION_2 = 2;
static const int CONVERSATION_SERVICE_MAJOR_VERSION_1 = 1;

static const int CONVERSATION_SERVICE_MINOR_VERSION_19 = 19;
static const int CONVERSATION_SERVICE_MINOR_VERSION_18 = 18;
static const int CONVERSATION_SERVICE_MINOR_VERSION_17 = 17;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_16 = 16;
static const int CONVERSATION_SERVICE_MINOR_VERSION_15 = 15;
static const int CONVERSATION_SERVICE_MINOR_VERSION_14 = 14;
static const int CONVERSATION_SERVICE_MINOR_VERSION_13 = 13;
static const int CONVERSATION_SERVICE_MINOR_VERSION_12 = 12;
static const int CONVERSATION_SERVICE_MINOR_VERSION_11 = 11;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_10 = 10;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_9 = 9;
static const int CONVERSATION_SERVICE_MINOR_VERSION_8 = 8;
static const int CONVERSATION_SERVICE_MINOR_VERSION_7 = 7;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_6 = 6;
static const int CONVERSATION_SERVICE_MINOR_VERSION_5 = 5;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_4 = 4;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_2 = 2;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_1 = 1;
static const int CONVERSATION_SERVICE_MINOR_VERSION_0 = 0;*/

//static const int MAX_MAJOR_VERSION = CONVERSATION_SERVICE_MAJOR_VERSION_2;

// The maximum minor number that is supported by the major version 2.
//static const int MAX_MINOR_VERSION_2 = CONVERSATION_SERVICE_MINOR_VERSION_19;
//static const int MAX_MINOR_VERSION_1 = CONVERSATION_SERVICE_MINOR_VERSION_0;

/*
 * <pre>
 *
 *
 * Date: 2018/10/05
 *
 * majorVersion: 2
 * minorVersion: 7
 *
 * ResetConversationIQ:
 *  Schema version 3
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 4
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 * InviteGroupIQ
 *  Schema version 1
 * RevokeInviteGroupIQ
 *  Schema version 1
 * JoinGroupIQ
 *  Schema version 1
 * LeaveGroupIQ
 *  Schema version 1
 * UpdateGroupMemberIQ
 *  Schema version 1
 * OnResultGroupIQ
 *  Schema version 1
 * OnResultJoinIQ
 *  Schema version 1
 *
 * Date: 2018/09/22
 *
 * majorVersion: 2
 * minorVersion: 6
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 4
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 * Date: 2018/09/03
 *
 * majorVersion: 2
 * minorVersion: 5
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 4
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 *
 * Date: 2018/04/24
 *
 * majorVersion: 2
 * minorVersion: 4
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 4
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 *
 * Date: 2017/10/25
 *
 * majorVersion: 2
 * minorVersion: 3
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 3
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 * Date: 2017/01/29
 *
 * majorVersion: 2
 * minorVersion: 2
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 3
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 * Date: 2016/12/29
 *
 * majorVersion: 2
 * minorVersion: 1
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 3
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 2
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 2
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 * UpdateDescriptorTimestampIQ
 *  Schema version 1
 * OnUpdateDescriptorTimestampIQ
 *  Schema version 1
 *
 * Date: 2016/09/08
 *
 * majorVersion: 2
 * minorVersion: 0
 *
 * ResetConversationIQ:
 *  Schema version 2
 * OnResetConversationIQ
 *  Schema version 2
 * PushObjectIQ
 *  Schema version 2
 * OnPushObjectIQ
 *  Schema version 2
 * PushTransientObjectIQ
 *  Schema version 1
 * OnPushTransientObjectIQ
 *  Schema version 1
 * PushFileIQ
 *  Schema version 1
 * OnPushFileIQ
 *  Schema version 1
 * PushFileChunkIQ
 *  Schema version 1
 * OnPushFileChunkIQ
 *  Schema version 1
 *
 *
 * majorVersion: 1
 * minorVersion: 0
 *
 * ResetConversationIQ
 *  Schema version 1
 * OnResetConversationIQ
 *  Schema version 1
 * PushObjectIQ
 *  Schema version 1
 * OnPushObjectIQ
 *  Schema version 1
 *
 * </pre>
 */

static NSUUID* NOT_DEFINED_PEER_TWINCODE_OUTBOUND_ID;

static const int SERIALIZER_BUFFER_DEFAULT_SIZE = 1024;

//
// Interface: TLConversationServiceAssertPoint ()
//

@implementation TLConversationServiceAssertPoint

TL_CREATE_ASSERT_POINT(RESET_CONVERSATION, 100)
TL_CREATE_ASSERT_POINT(SERVICE, 101)
TL_CREATE_ASSERT_POINT(EXCEPTION, 102)
TL_CREATE_ASSERT_POINT(PROCESS_IQ, 103)
TL_CREATE_ASSERT_POINT(PROCESS_LEGACY_IQ, 104)
TL_CREATE_ASSERT_POINT(SERIALIZE_ERROR, 105)

@end

//
// Implementation: TLConversationServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceConfiguration"

@implementation TLConversationServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdConversationService version:[TLConversationService VERSION] serviceOn:NO];
    
    return self;
}

@end

//
// Implementation: TLConversationHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationHandler"

@interface TLConversationHandler ()

@property (nonatomic, readonly) BOOL padding;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLBinaryPacketListener> *binaryPacketListeners;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSNumber *, TLDescriptor *> *requests;
@property (nonatomic, nullable) TLGeolocationDescriptor *geolocationDescriptor;

@end

//
// Implementation: TLConversationDescriptorPair
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationDescriptorPair"

@implementation TLConversationDescriptorPair

- (nonnull instancetype)initWithConversation:(nonnull id<TLConversation>)conversation descriptor:(nullable TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ initWithConversation: %@ descriptor: %@", LOG_TAG, conversation, descriptor);
    
    self = [super init];
    if (self) {
        _conversation = conversation;
        _descriptor = descriptor;
    }
    return self;
}

@end

//
// Implementation: TLDescriptorAnnotationPair
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptorAnnotationPair"

@implementation TLDescriptorAnnotationPair

- (nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound annotation:(nonnull TLDescriptorAnnotation *)annotation {
    DDLogVerbose(@"%@ initWithTwincodeOutbound: %@ annotation: %@", LOG_TAG, twincodeOutbound, annotation);
    
    self = [super init];
    if (self) {
        _twincodeOutbound = twincodeOutbound;
        _annotation = annotation;
    }
    return self;
}

@end

//
// Implementation: TLPeerConnectionPacketHandler ()
//

@implementation TLPeerConnectionPacketHandler

- (nonnull instancetype)initWithSerializer:(nonnull TLSerializer *)serializer listener:(nonnull TLPeerConnectionBinaryPacketListener)listener {
    
    self = [super init];
    if (self) {
        _serializer = serializer;
        _listener = listener;
    }
    return self;
}

@end

//
// Implementation: TLConversationHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationHandler"

@implementation TLConversationHandler

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService {
    DDLogVerbose(@"%@ initWithPeerConnectionService", LOG_TAG);
    
    self = [super init];
    if (self) {
        _peerConnectionService = peerConnectionService;
        _serializerFactory = peerConnectionService.twinlife.serializerFactory;
        _binaryPacketListeners = [[NSMutableDictionary alloc] init];
        _requests = [[NSMutableDictionary alloc] init];
        _padding = NO;
        
        // Register the binary IQ handlers for the responses.
        __weak TLConversationHandler *handler = self;
        [self addPacketListener:[TLPushObjectIQ SERIALIZER_5] listener:^(TLBinaryPacketIQ * iq) {
            [handler onPushObjectWithIQ:iq];
        }];
        [self addPacketListener:[TLOnPushObjectIQ SERIALIZER_3] listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPushWithIQ:iq];
        }];

        [self addPacketListener:[TLPushTwincodeIQ SERIALIZER_3] listener:^(TLBinaryPacketIQ * iq) {
            [handler onPushTwincodeWithIQ:iq];
        }];
        [self addPacketListener:[TLPushTwincodeIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onPushTwincodeWithIQ:iq];
        }];
        [self addPacketListener:[TLOnPushTwincodeIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPushWithIQ:iq];
        }];

        [self addPacketListener:[TLPushGeolocationIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onPushGeolocationWithIQ:iq];
        }];
        [self addPacketListener:[TLOnPushGeolocationIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPushWithIQ:iq];
        }];
        [self addPacketListener:[TLUpdateGeolocationIQ SERIALIZER_1] listener:^(TLBinaryPacketIQ * iq) {
            [handler onUpdateGeolocationWithIQ:iq];
        }];
        [self addPacketListener:[TLOnUpdateGeolocationIQ SERIALIZER_1] listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPushWithIQ:iq];
        }];
        [self addPacketListener:[TLUpdateTimestampIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onUpdateTimestampWithIQ:iq];
        }];
        [self addPacketListener:[TLOnUpdateTimestampIQ SERIALIZER_2] listener:^(TLBinaryPacketIQ * iq) {
            [handler onOnPushWithIQ:iq];
        }];
    }
    return self;
}

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener {
    DDLogVerbose(@"%@ addPacketListener: %@", LOG_TAG, serializer);
    
    TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
    self.binaryPacketListeners[key] = listener;
    [self.serializerFactory addSerializer:serializer];
}

- (nonnull TLPeerConnectionDataChannelConfiguration *)configurationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sdpEncryptionStatus:(TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus {
    DDLogVerbose(@"%@ configurationWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:TLConversationService.VERSION leadingPadding:NO];
}

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelOpenWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
}

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onDataChannelClosedWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
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

- (BOOL)sendWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ sendWithDescriptor", LOG_TAG);
    
    int64_t requestId = [self newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.requests) {
        self.requests[lRequestId] = descriptor;
    }

    BOOL sent;
    if ([descriptor isKindOfClass:[TLObjectDescriptor class]]) {
        TLPushObjectIQ *pushObjectIQ = [[TLPushObjectIQ alloc] initWithSerializer:[TLPushObjectIQ SERIALIZER_5] requestId:requestId objectDescriptor:(TLObjectDescriptor *)descriptor];
        sent = [self sendMessageWithIQ:pushObjectIQ statType:TLPeerConnectionServiceStatTypeIqSetPushObject];
    
    } else if ([descriptor isKindOfClass:[TLTwincodeDescriptor class]]) {
        TLPushTwincodeIQ *pushTwincodeIQ = [[TLPushTwincodeIQ alloc] initWithSerializer:[TLPushTwincodeIQ SERIALIZER_2] requestId:requestId twincodeDescriptor:(TLTwincodeDescriptor *)descriptor];
        sent = [self sendMessageWithIQ:pushTwincodeIQ statType:TLPeerConnectionServiceStatTypeIqSetPushTwincode];

    } else if ([descriptor isKindOfClass:[TLGeolocationDescriptor class]]) {
        TLPushGeolocationIQ *pushGeolocationIQ = [[TLPushGeolocationIQ alloc] initWithSerializer:[TLPushGeolocationIQ SERIALIZER_2] requestId:requestId geolocationDescriptor:(TLGeolocationDescriptor *)descriptor];
        sent = [self sendMessageWithIQ:pushGeolocationIQ statType:TLPeerConnectionServiceStatTypeIqSetPushGeolocation];

    } else {
        sent = NO;
    }

    if (!sent) {
        @synchronized (self.requests) {
            [self.requests removeObjectForKey:lRequestId];
        }
        if (descriptor.sentTimestamp == 0) {
            descriptor.sentTimestamp = -1L;
        }
    } else if (descriptor.sentTimestamp <= 0) {
        descriptor.sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    }
    return sent;
}

- (BOOL)updateWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta {
    DDLogVerbose(@"%@ updateWithDescriptor: %@", LOG_TAG, descriptor);
    
    int64_t requestId = [self newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.requests) {
        self.requests[lRequestId] = descriptor;
    }

    int64_t updatedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    descriptor.longitude = longitude;
    descriptor.latitude = latitude;
    descriptor.altitude = altitude;
    descriptor.mapLatitudeDelta = mapLatitudeDelta;
    descriptor.mapLongitudeDelta = mapLongitudeDelta;

    TLUpdateGeolocationIQ *updateGeolocationIQ = [[TLUpdateGeolocationIQ alloc] initWithSerializer:[TLUpdateGeolocationIQ SERIALIZER_1] requestId:requestId updatedTimestamp:updatedTimestamp longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta];
    return [self sendMessageWithIQ:updateGeolocationIQ statType:TLPeerConnectionServiceStatTypeIqSetPushGeolocation];
}

- (BOOL)deleteWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ deleteWithDescriptor: %@", LOG_TAG, descriptor);
    
    int64_t requestId = [self newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self.requests) {
        self.requests[lRequestId] = descriptor;
    }
    int64_t timestamp = [[NSDate date] timeIntervalSince1970] * 1000;

    TLUpdateTimestampIQ *updateTimestampIQ = [[TLUpdateTimestampIQ alloc] initWithSerializer:[TLUpdateTimestampIQ SERIALIZER_2] requestId:requestId descriptorId:descriptor.descriptorId timestampType:TLUpdateDescriptorTimestampTypeDelete timestamp:timestamp];
    return [self sendMessageWithIQ:updateTimestampIQ statType:TLPeerConnectionServiceStatTypeIqSetUpdateObject];
}

+ (BOOL)markReadWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ markReadWithDescriptor: %@", LOG_TAG, descriptor);

    if (descriptor.readTimestamp <= 0) {
        descriptor.readTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        return YES;
    } else {
        return NO;
    }
}

- (long)newRequestId {
    DDLogVerbose(@"%@ newRequestId", LOG_TAG);
    
    @throw [TLUnsupportedException exceptionWithName:@"newRequestId not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (nullable TLGeolocationDescriptor *)currentGeolocation {
    DDLogVerbose(@"%@ currentGeolocation: %@", LOG_TAG, self.geolocationDescriptor);

    return self.geolocationDescriptor;
}

- (void)onPopWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopWithDescriptor: %@", LOG_TAG, descriptor);
    
    @throw [TLUnsupportedException exceptionWithName:@"onPopWithDescriptor not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (void)onUpdateGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor {
    DDLogVerbose(@"%@ onUpdateGeolocationWithDescriptor: %@", LOG_TAG, descriptor);
    
    @throw [TLUnsupportedException exceptionWithName:@"onUpdateGeolocationWithDescriptor not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (void)onReadWithDescriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp {
    DDLogVerbose(@"%@ onReadWithDescriptorId: %@ timestamp: %lld", LOG_TAG, descriptorId, timestamp);
    
    @throw [TLUnsupportedException exceptionWithName:@"onReadWithDescriptorId not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (void)onDeleteWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ onDeleteWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    @throw [TLUnsupportedException exceptionWithName:@"onDeleteWithDescriptorId not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (void)onPushObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onPushObjectWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLPushObjectIQ class]]) {
        return;
    }
    
    TLPushObjectIQ *pushObjectIQ = (TLPushObjectIQ *)iq;
    TLDescriptor *descriptor = pushObjectIQ.objectDescriptor;
    descriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    [self onPopWithDescriptor:descriptor];
    
    int deviceState = 2;
    TLOnPushIQ *onPushObjectIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushObjectIQ SERIALIZER_3] requestId:iq.requestId deviceState:deviceState receivedTimestamp:descriptor.receivedTimestamp];
    [self sendMessageWithIQ:onPushObjectIQ statType:TLPeerConnectionServiceStatTypeIqResultPushObject];
}

- (void)onPushTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onPushTwincodeWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLPushTwincodeIQ class]]) {
        return;
    }
    
    TLPushTwincodeIQ *pushTwincodeIQ = (TLPushTwincodeIQ *)iq;
    TLDescriptor *descriptor = pushTwincodeIQ.twincodeDescriptor;
    descriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    [self onPopWithDescriptor:descriptor];
    
    int deviceState = 2;
    TLOnPushIQ *onPushObjectIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushTwincodeIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:descriptor.receivedTimestamp];
    [self sendMessageWithIQ:onPushObjectIQ statType:TLPeerConnectionServiceStatTypeIqResultPushTwincode];
}

- (void)onPushGeolocationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onPushGeolocationWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLPushGeolocationIQ class]]) {
        return;
    }
    
    TLPushGeolocationIQ *pushGeolocationIQ = (TLPushGeolocationIQ *)iq;
    TLGeolocationDescriptor *descriptor = pushGeolocationIQ.geolocationDescriptor;
    descriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    self.geolocationDescriptor = descriptor;
    [self onPopWithDescriptor:descriptor];
    
    int deviceState = 2;
    TLOnPushIQ *onPushObjectIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushGeolocationIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:descriptor.receivedTimestamp];
    [self sendMessageWithIQ:onPushObjectIQ statType:TLPeerConnectionServiceStatTypeIqResultPushGeolocation];
}

- (void)onUpdateGeolocationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onUpdateGeolocationWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLUpdateGeolocationIQ class]]) {
        return;
    }
    
    TLUpdateGeolocationIQ *updateGeolocationIQ = (TLUpdateGeolocationIQ *)iq;
    int64_t receivedTimestamp;
    if (self.geolocationDescriptor) {
        receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        self.geolocationDescriptor.longitude = updateGeolocationIQ.longitude;
        self.geolocationDescriptor.latitude = updateGeolocationIQ.latitude;
        self.geolocationDescriptor.altitude = updateGeolocationIQ.altitude;
        self.geolocationDescriptor.mapLatitudeDelta = updateGeolocationIQ.mapLatitudeDelta;
        self.geolocationDescriptor.mapLongitudeDelta = updateGeolocationIQ.mapLongitudeDelta;

        self.geolocationDescriptor.receivedTimestamp = receivedTimestamp;
        [self onUpdateGeolocationWithDescriptor:self.geolocationDescriptor];
    } else {
        receivedTimestamp = -1L;
    }

    int deviceState = 2;
    TLOnPushIQ *onUpdateGeolocationIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdateGeolocationIQ SERIALIZER_1] requestId:iq.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];
    [self sendMessageWithIQ:onUpdateGeolocationIQ statType:TLPeerConnectionServiceStatTypeIqResultPushGeolocation];
}

- (void)onUpdateTimestampWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onUpdateTimestampWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLUpdateTimestampIQ class]]) {
        return;
    }
    
    TLUpdateTimestampIQ *updateTimestampIQ = (TLUpdateTimestampIQ *)iq;
    switch (updateTimestampIQ.timestampType) {
        case TLUpdateDescriptorTimestampTypeRead:
            [self onReadWithDescriptorId:updateTimestampIQ.descriptorId timestamp:updateTimestampIQ.timestamp];
            break;

        case TLUpdateDescriptorTimestampTypeDelete:
            if (self.geolocationDescriptor && [self.geolocationDescriptor.descriptorId isEqual:updateTimestampIQ.descriptorId]) {
                self.geolocationDescriptor = nil;
            }
            [self onDeleteWithDescriptorId:updateTimestampIQ.descriptorId];
            break;

        case TLUpdateDescriptorTimestampTypePeerDelete:
            break;

        default:
            break;
    }

    int deviceState = 2;
    TLOnPushIQ *onUpdateTimestampIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdateTimestampIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
    [self sendMessageWithIQ:onUpdateTimestampIQ statType:TLPeerConnectionServiceStatTypeIqResultUpdateObject];
}

- (void)onOnPushWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onOnPushWithIQ: %@", LOG_TAG, iq);

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLDescriptor *descriptor;
    @synchronized (self.requests) {
        descriptor = self.requests[lRequestId];
        if (descriptor) {
            [self.requests removeObjectForKey:lRequestId];
        }
    }
    if (descriptor.receivedTimestamp <= 0) {
        descriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    }
}

@end

//
// Interface: TLDescriptorFactory
//

@implementation TLDescriptorFactory

- (nonnull TLDescriptorId *)newDescriptorId {
    DDLogVerbose(@"%@ newDescriptorId", LOG_TAG);

    @throw [TLUnsupportedException exceptionWithName:@"newDescriptorId not implemented" reason:@"method must be overriden" userInfo:nil];
}

- (nonnull TLDescriptor *)createWithMessage:(nonnull NSString *)message replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ createWithMessage: %@ replyTo: %@ copyAllowed: %d", LOG_TAG, message, replyTo, copyAllowed);

    TLDescriptorId *descriptorId = [self newDescriptorId];
    return [[TLObjectDescriptor alloc] initWithDescriptorId:descriptorId conversationId:0 sendTo:nil replyTo:replyTo message:message copyAllowed:copyAllowed expireTimeout:0];
}

- (nonnull TLGeolocationDescriptor *)createWithLongitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ createWithLongitude: %f replyTo: %@ copyAllowed: %d", LOG_TAG, latitude, replyTo, copyAllowed);

    TLDescriptorId *descriptorId = [self newDescriptorId];
    return [[TLGeolocationDescriptor alloc] initWithDescriptorId:descriptorId conversationId:0 sendTo:nil replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta expireTimeout:0];
}

- (nonnull TLDescriptor *)createWithTwincode:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey  replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ createWithTwincode: %@ schemaId: %@ replyTo: %@ copyAllowed: %d", LOG_TAG, twincodeId, schemaId, replyTo, copyAllowed);

    TLDescriptorId *descriptorId = [self newDescriptorId];
    return [[TLTwincodeDescriptor alloc] initWithDescriptorId:descriptorId conversationId:0 sendTo:nil replyTo:replyTo twincodeId:twincodeId schemaId:schemaId publicKey:publicKey copyAllowed:copyAllowed expireTimeout:0];
}

@end

//
// Implementation: TLDescriptorId
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptorId"

@implementation TLDescriptorId

- (nonnull instancetype)initWithId:(long)id twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId {
    
    self = [super init];
    
    if (self) {
        _id = id;
        _twincodeOutboundId = twincodeOutboundId;
        _sequenceId = sequenceId;
    }
    return self;
}

- (instancetype)initWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld", LOG_TAG, twincodeOutboundId, sequenceId);
    
    self = [super init];
    
    if (self) {
        _id = 0;
        _twincodeOutboundId = twincodeOutboundId;
        _sequenceId = sequenceId;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)value {
    DDLogVerbose(@"%@ initWithString: %@", LOG_TAG, value);
    
    self = [super init];
    
    if (self) {
        NSUInteger pos = [value rangeOfString:@":"].location;
        if (pos <= 0) {
            return nil;
        }
        NSString *seqString = [value substringFromIndex:pos + 1];
        
        _id = 0;
        _twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:[value substringToIndex:pos]];
        _sequenceId = [seqString longLongValue];
        if (!_twincodeOutboundId) {
            return nil;
        }
    }
    return self;
}

- (NSString *)toString {
    
    return [NSString stringWithFormat:@"%@:%lld", self.twincodeOutboundId.UUIDString, self.sequenceId];
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return true;
    }
    if (object == nil || ![object isKindOfClass:[TLDescriptorId class]]) {
        return false;
    }
    TLDescriptorId* descriptorId = (TLDescriptorId *)object;
    return [descriptorId.twincodeOutboundId isEqual:self.twincodeOutboundId] && descriptorId.sequenceId == self.sequenceId;
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.twincodeOutboundId.hash;
    result = 31 * result + (NSUInteger)(self.sequenceId ^ (self.sequenceId >> 32));
    return result;
}

- (NSString *)description {
    
    return [NSString stringWithFormat:@"%@:%lld\n", self.twincodeOutboundId.UUIDString, self.sequenceId];
}

@end


//
// Implementation: TLConversationService
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationService"

@implementation TLConversationService

+ (void) initialize {
    
    NOT_DEFINED_PEER_TWINCODE_OUTBOUND_ID = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

+ (NSString *)VERSION {
    
    return CONVERSATION_SERVICE_VERSION;
}

+ (int)MAX_GROUP_MEMBERS {
    
    return CONVERSATION_MAX_GROUP_MEMBERS;
}

+ (int)MAJOR_VERSION_1 {
    
    return CONVERSATION_SERVICE_MAJOR_VERSION_1;
}

+ (int)CONVERSATION_SERVICE_MAJOR_VERSION_2 {
    
    return CONVERSATION_SERVICE_MAJOR_VERSION_2;
}

+ (int)CONVERSATION_SERVICE_GROUP_MINOR_VERSION {
    
    return CONVERSATION_SERVICE_MINOR_VERSION_7;
}

+ (int)CONVERSATION_SERVICE_GROUP_RESET_CONVERSATION_MINOR_VERSION {
    
    return CONVERSATION_SERVICE_MINOR_VERSION_7;
}

+ (int)CONVERSATION_SERVICE_GEOLOCATION_MINOR_VERSION {
    
    return CONVERSATION_SERVICE_MINOR_VERSION_8;
}

+ (int)CONVERSATION_SERVICE_PUSH_COMMAND_MINOR_VERSION {
    
    return CONVERSATION_SERVICE_MINOR_VERSION_11;
}

- (instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife peerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    if (self) {
        _serviceProvider = [[TLConversationServiceProvider alloc] initWithService:self database:twinlife.databaseService];
        _peerConnectionService = peerConnectionService;
        _peerConnectionId2Conversation = [[NSMutableDictionary alloc] init];
        const char *executorQueueName = "conversationExecutorQueue";
        _executorQueue = dispatch_queue_create(executorQueueName, DISPATCH_QUEUE_SERIAL);
        _scheduler = [[TLConversationServiceScheduler alloc] initWithTwinlife:twinlife conversationService:self serviceProvider:_serviceProvider executorQueue:_executorQueue];
        posix_memalign((void **)&_requestId, 8, 8);
        *_requestId = 0L;
        _acceptedPushTwincode = [[NSMutableSet alloc] init];
        _needResyncGroups = NO;
        _lockIdentifier = 0;
        _twincodeOutboundService = [twinlife getTwincodeOutboundService];
        _twincodeInboundService = [twinlife getTwincodeInboundService];
        _groupManager = [[TLGroupConversationManager alloc] initWithConversationService:self];
        
        _binaryPacketListeners = [[NSMutableDictionary alloc] init];

        // Register the binary IQ handlers for the responses.
        __weak TLConversationService *handler = self;

        // Synchronize
        // Note: the processSynchronizeIQ() is special and cannot be handled through the packet listener.
        [self addPacketListener:TLOnSynchronizeIQ.SERIALIZER_1 listener:^(TLConversationConnection *connection, TLBinaryPacketIQ *iq) {
            [handler processOnSynchronizeIQWithConnection:connection iq:(TLOnSynchronizeIQ *)iq];
        }];

        // Signature
        [self addPacketListener:[TLSignatureInfoIQ SERIALIZER] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processSignatureInfoIQWithConnection:connection iq:(TLSignatureInfoIQ *)iq];
        }];
        [self addPacketListener:[TLOnSignatureInfoIQ SERIALIZER] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnSignatureInfoIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];
        [self addPacketListener:[TLAckSignatureInfoIQ SERIALIZER] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processAckSignatureInfoIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Reset conversation
        [self addPacketListener:TLResetConversationIQ.SERIALIZER_4 listener:^(TLConversationConnection *connection, TLBinaryPacketIQ *iq) {
            [handler processResetConversationIQWithConnection:connection iq:(TLResetConversationIQ *)iq];
        }];
        [self addPacketListener:TLOnResetConversationIQ.SERIALIZER_3 listener:^(TLConversationConnection *connection, TLBinaryPacketIQ *iq) {
            [handler processOnResetConversationIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];
        
        // Push object
        [self addPacketListener:[TLPushObjectIQ SERIALIZER_5] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushObjectIQWithConnection:connection iq:(TLPushObjectIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushObjectIQ SERIALIZER_3] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushObjectIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];
        
        // Update object
        [self addPacketListener:[TLUpdateDescriptorIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processUpdateObjectIQWithConnection:connection iq:(TLUpdateDescriptorIQ *)iq];
        }];
        [self addPacketListener:[TLOnUpdateDescriptorIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnUpdateObjectIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Push transient and push command object (same handler for both).
        [self addPacketListener:[TLPushTransientIQ SERIALIZER_3] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushTransientIQWithConnection:connection iq:(TLPushTransientIQ *)iq];
        }];
        [self addPacketListener:[TLPushCommandIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushTransientIQWithConnection:connection iq:(TLPushTransientIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushCommandIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushCommandIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Push twincode
        [self addPacketListener:[TLPushTwincodeIQ SERIALIZER_3] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushTwincodeIQWithConnection:connection iq:(TLPushTwincodeIQ *)iq];
        }];
        [self addPacketListener:[TLPushTwincodeIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushTwincodeIQWithConnection:connection iq:(TLPushTwincodeIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushTwincodeIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushTwincodeIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Push geolocation
        [self addPacketListener:[TLPushGeolocationIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushGeolocationIQWithConnection:connection iq:(TLPushGeolocationIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushGeolocationIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushGeolocationIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Push file
        [self addPacketListener:[TLPushFileIQ SERIALIZER_7] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushFileIQWithConnection:connection iq:(TLPushFileIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushFileIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushFileIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];
        [self addPacketListener:[TLPushThumbnailIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushThumbnailIQWithConnection:connection iq:(TLPushFileChunkIQ *)iq];
        }];
        [self addPacketListener:[TLPushFileChunkIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processPushFileChunkIQWithConnection:connection iq:(TLPushFileChunkIQ *)iq];
        }];
        [self addPacketListener:[TLOnPushFileChunkIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnPushFileChunkIQWithConnection:connection iq:(TLOnPushFileChunkIQ *)iq];
        }];

        // Update timestamps
        [self addPacketListener:[TLUpdateTimestampIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processUpdateTimestampIQWithConnection:connection iq:(TLUpdateTimestampIQ *)iq];
        }];
        [self addPacketListener:[TLOnUpdateTimestampIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnUpdateTimestampIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Update annotation
        [self addPacketListener:[TLUpdateAnnotationsIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processUpdateAnnotationsIQWithConnection:connection iq:(TLUpdateAnnotationsIQ *)iq];
        }];
        [self addPacketListener:[TLOnUpdateAnnotationsIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnUpdateAnnotationsIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Invite group
        [self addPacketListener:[TLInviteGroupIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processInviteGroupIQWithConnection:connection iq:(TLInviteGroupIQ *)iq];
        }];
        [self addPacketListener:[TLOnInviteGroupIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnInviteGroupIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];

        // Join group
        [self addPacketListener:[TLJoinGroupIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processJoinGroupIQWithConnection:connection iq:(TLJoinGroupIQ *)iq];
        }];
        [self addPacketListener:[TLOnJoinGroupIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnJoinGroupIQWithConnection:connection iq:(TLOnJoinGroupIQ *)iq];
        }];

        // Update group member permission
        [self addPacketListener:[TLUpdatePermissionsIQ SERIALIZER_2] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processUpdatePermissionsIQWithConnection:connection iq:(TLUpdatePermissionsIQ *)iq];
        }];
        [self addPacketListener:[TLOnUpdatePermissionsIQ SERIALIZER_1] listener:^(TLConversationConnection *connection, TLBinaryPacketIQ * iq) {
            [handler processOnUpdatePermissionsIQWithConnection:connection iq:(TLOnPushIQ *)iq];
        }];
    }
    return self;
}

#pragma mark - BaseServiceImpl

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLConversationServiceConfiguration* conversationServiceConfiguration = [[TLConversationServiceConfiguration alloc] init];
    TLConversationServiceConfiguration* serviceConfiguration = (TLConversationServiceConfiguration *) baseServiceConfiguration;
    conversationServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    conversationServiceConfiguration.enableScheduler = serviceConfiguration.enableScheduler;
    conversationServiceConfiguration.lockIdentifier = serviceConfiguration.lockIdentifier;
    self.lockIdentifier = conversationServiceConfiguration.lockIdentifier;
    self.serviceConfiguration = conversationServiceConfiguration;
    self.serviceOn = conversationServiceConfiguration.isServiceOn;
    self.scheduler.enable = conversationServiceConfiguration.enableScheduler;
    self.configured = YES;

    // Move the conversation files from the old location to the application shared group container.
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *oldPath = [[NSString alloc] initWithFormat:@"%@/Conversations", documentsPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *newPath = [TLTwinlife getAppGroupPath:fileManager path:@"Conversations"];
    if ([fileManager fileExistsAtPath:oldPath] && ![fileManager fileExistsAtPath:newPath]) {
        DDLogInfo(@"%@ configure: migrate conversations files to App Shared container", LOG_TAG);
        NSError *error;
        
        [fileManager moveItemAtPath:oldPath toPath:newPath error:&error];
        if (error) {
            DDLogError(@"%@ configure: failed to move database: %@", LOG_TAG, error);
        }
    }
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@: onTwinlifeReady", LOG_TAG);

    // Register the binary IQ handlers for the responses.
    __weak TLConversationService *handler = self;

    [self.twincodeInboundService addListenerWithAction:[TLConversationProtocol ACTION_CONVERSATION_SYNCHRONIZE] listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [handler onConversationSynchronizeWithInvocation:invocation];
    }];
    [self.twincodeInboundService addListenerWithAction:[TLConversationProtocol ACTION_CONVERSATION_NEED_SECRET] listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [handler onConversationNeedSecretWithInvocation:invocation];
    }];
    [self.twincodeInboundService addListenerWithAction:INVOKE_TWINCODE_ACTION_CONVERSATION_REFRESH_SECRET listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [handler onConversationRefreshSecretWithInvocation:invocation];
    }];
    [self.twincodeInboundService addListenerWithAction:INVOKE_TWINCODE_ACTION_CONVERSATION_ON_REFRESH_SECRET listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [handler onConversationRefreshSecretWithInvocation:invocation];
    }];
    [self.twincodeInboundService addListenerWithAction:INVOKE_TWINCODE_ACTION_CONVERSATION_VALIDATE_SECRET listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [handler onConversationRefreshSecretWithInvocation:invocation];
    }];
    [self.groupManager onTwinlifeReady];
    [self.scheduler loadOperations];
}

/// Handle the conversation synchronize twincode invocation: the peer has something to send for us.
- (TLBaseServiceErrorCode)onConversationSynchronizeWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onConversationSynchronizeWithInvocation", LOG_TAG);
    
    TLTwincodeOutbound *twincodeOutbound = invocation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = invocation.subject.peerTwincodeOutbound;
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    // We can receive a process invocation on the group: get the group member that sent us the synchronize invocation.
    NSUUID *peerTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:[TLConversationProtocol invokeTwincodeActionMemberTwincodeOutboundId] list:invocation.attributes];
    if (peerTwincodeId) {

        id<TLConversation> conversation = [self getConversationWithSubject:invocation.subject];
        if (!conversation || ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
            return TLBaseServiceErrorCodeExpired;
        }

        TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
        TLGroupMemberConversationImpl *groupMemberConversation = [groupConversation getMemberWithTwincodeId:peerTwincodeId];
        if (!groupMemberConversation) {
            return TLBaseServiceErrorCodeExpired;
        }
        [self synchronizeWithConversation:groupMemberConversation];

    } else {
        id<TLConversation> conversation = [self getOrCreateConversationWithSubject:invocation.subject create:YES];
        if (!conversation || ![conversation isKindOfClass:[TLConversationImpl class]]) {
            return TLBaseServiceErrorCodeExpired;
        }

        [self synchronizeWithConversation:(TLConversationImpl *)conversation];
    }
    return TLBaseServiceErrorCodeSuccess;
}

/// Handle the conversation need-secret twincode invocation: the peer needs our public key and secrets and failed
/// * to accept an incoming encrypted P2P connection:
/// * - if we know the peer public key, make a refresh-secret secure invocation to it,
/// * - if we don't know its public key, or, our identity twincode has no public key, report the NOT_AUTHORIZED_OPERATION error.
- (TLBaseServiceErrorCode)onConversationNeedSecretWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onConversationNeedSecretWithInvocation", LOG_TAG);
    
    TLTwincodeOutbound *twincodeOutbound = invocation.subject.twincodeOutbound;
    TLTwincodeInbound *twincodeInbound = invocation.subject.twincodeInbound;
    if (!twincodeOutbound || !twincodeInbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    // We can receive a process invocation on the group: get the group member that sent us the synchronize invocation.
    NSUUID *peerTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:[TLConversationProtocol invokeTwincodeActionMemberTwincodeOutboundId] list:invocation.attributes];
    TLTwincodeOutbound *peerTwincodeOutbound;
    if (peerTwincodeId) {

        id<TLConversation> conversation = [self getConversationWithSubject:invocation.subject];
        if (!conversation || ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
            return TLBaseServiceErrorCodeExpired;
        }

        TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
        TLGroupMemberConversationImpl *groupMemberConversation = [groupConversation getMemberWithTwincodeId:peerTwincodeId];
        if (!groupMemberConversation) {
            return TLBaseServiceErrorCodeExpired;
        }
        peerTwincodeOutbound = groupMemberConversation.peerTwincodeOutbound;

    } else {
        peerTwincodeOutbound = invocation.subject.peerTwincodeOutbound;
    }
    if (!peerTwincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    // If we don't know the peer public key, we cannot proceed.
    if (![peerTwincodeOutbound isSigned]) {
        return TLBaseServiceErrorCodeNotAuthorizedOperation;
    }

    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] initWithCapacity:1];
    [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:@"requestTimestamp" longValue:[[NSDate date] timeIntervalSince1970] * 1000]];

    [self.twincodeOutboundService createPrivateKeyWithTwincode:twincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound1) {
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            return;
        }

        if (errorCode != TLBaseServiceErrorCodeSuccess) {
            [self.twincodeInboundService acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
            return;
        }
        [self.twincodeOutboundService secureInvokeTwincodeWithTwincode:twincodeOutbound senderTwincode:twincodeOutbound receiverTwincode:peerTwincodeOutbound options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateNewSecret) action:INVOKE_TWINCODE_ACTION_CONVERSATION_REFRESH_SECRET attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
            if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                return;
            }
            [self.twincodeInboundService acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
        }];
    }];

    return TLBaseServiceErrorCodeQueued;
}

/**
 * Handle the conversation refresh secret twincode invocation: the peer does not know our secret or it is not able
 * to setup a P2P session with existing secrets.  This is handled in several steps by the same invocation handler
 * because these steps are very close.  The global process is the following:
 *
 * DEVICE-1  -- invokeTwincode("need-refresh") ===>        DEVICE-2
 *                                                         createPrivateKey()
 *                                                         CREATE_NEW_SECRET
 *          <== secureInvokeTwincode("refresh-secret") --
 * getSignedTwincode()
 * save DEVICE-2 secret
 * SEND_SECRET
 *           -- secureInvokeTwincode("on-refresh-secret") ===>
 *                                                         getSignedTwincode()
 *                                                         save DEVICE-1 secret
 *                                                         validateSecrets(DEVICE-2, DEVICE-1)
 *          <== secureInvokeTwincode("validate-secret")   -- (no secret sent)
 * getSignedTwincode()
 * validateSecrets(DEVICE-1, DEVICE-2)
 *
 * A call to validateSecrets() is necessary after a CREATE_NEW_SECRET or SEND_SECRET to make the secret usable for encryption.
 * CREATE_NEW_SECRET generates a new secret 1 or secret 2.
 * SEND_SECRET sends the existing secret but it is created if it does not exist (which means a validateSecrets() is necessary).
 */
- (TLBaseServiceErrorCode)onConversationRefreshSecretWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onConversationRefreshSecretWithInvocation: %@", LOG_TAG, invocation);

    NSUUID *peerTwincodeOutboundId = invocation.peerTwincodeId;
    if (!invocation.publicKey || !peerTwincodeOutboundId || !invocation.attributes) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLTwincodeOutbound *twincodeOutbound = invocation.subject.twincodeOutbound;
    if (!twincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    // The secretKey can be null only for the validate-secret final invocation.
    if (!invocation.secretKey && ![invocation.action isEqualToString:INVOKE_TWINCODE_ACTION_CONVERSATION_VALIDATE_SECRET]) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    [self.twincodeOutboundService getSignedTwincodeWithTwincodeId:peerTwincodeOutboundId publicKey:invocation.publicKey keyIndex:invocation.keyIndex secretKey:invocation.secretKey trustMethod:TLTrustMethodNone withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *peerTwincodeOutbound) {

        // If we are offline or timed out don't acknowledge the invocation.
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            return;
        }
        if (errorCode != TLBaseServiceErrorCodeSuccess || !peerTwincodeOutbound) {
            [self.twincodeInboundService acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
            return;
        }

        if ([invocation.action isEqualToString:INVOKE_TWINCODE_ACTION_CONVERSATION_VALIDATE_SECRET]) {
            [[self.twinlife getCryptoService] validateSecretWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound];

            // Emit a log to track execution duration of the whole secret exchange process.
            int64_t startTime = [TLAttributeNameLongValue getLongAttributeWithName:@"requestTimestamp" list:invocation.attributes defaultValue:0];
            if (startTime > 0) {
                NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
                int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
                
                [attributes setObject:[NSString stringWithFormat:@"%lld", now - startTime] forKey:@"duration"];
                [attributes setObject:[invocation.invocationId UUIDString] forKey:@"invocationId"];
                [[self.twinlife getManagementService] logEventWithEventId:EVENT_ID_SECRET_EXCHANGE attributes:attributes flush:YES];
            }
            [self.twincodeInboundService acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
        } else {
            NSString *nextAction;
            int invokeOptions;
            if ([invocation.action isEqualToString:INVOKE_TWINCODE_ACTION_CONVERSATION_ON_REFRESH_SECRET]) {
                nextAction = INVOKE_TWINCODE_ACTION_CONVERSATION_VALIDATE_SECRET;
                invokeOptions = TLInvokeTwincodeUrgent;
            } else {
                nextAction = INVOKE_TWINCODE_ACTION_CONVERSATION_ON_REFRESH_SECRET;
                invokeOptions = (TLInvokeTwincodeUrgent | TLInvokeTwincodeSendSecret);
            }
            [self.twincodeOutboundService secureInvokeTwincodeWithTwincode:twincodeOutbound senderTwincode:twincodeOutbound receiverTwincode:peerTwincodeOutbound options:invokeOptions action:nextAction attributes:invocation.attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                if (errorCode == TLBaseServiceErrorCodeSuccess) {
                    [self.twincodeInboundService acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
                }
            }];
        }
    }];
    return TLBaseServiceErrorCodeQueued;
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@: onTwinlifeOnline", LOG_TAG);
    
    [super onTwinlifeOnline];
    
    [self.scheduler onTwinlifeOnline];
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@: onTwinlifeSuspend", LOG_TAG);

    [self.scheduler onTwinlifeSuspend];
}

- (void)onTwinlifeResume {
    DDLogVerbose(@"%@: onTwinlifeResume", LOG_TAG);

    if (self.twinlife.lastSuspendDate > 0) {
        [self.scheduler loadOperations];
    }
}

- (void)reloadOperations {
    DDLogVerbose(@"%@: reloadOperations", LOG_TAG);

    [self.scheduler loadOperations];
}

- (void)onSignOut {
    DDLogVerbose(@"%@: onSignOut", LOG_TAG);
    
    [super onSignOut];
    
    @synchronized(self) {
        [self.peerConnectionId2Conversation removeAllObjects];
        [self.scheduler removeAllOperations];
    }
    
    [self deleteAllFiles];
}

#pragma mark - TLConversationService

- (void)incomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId subject:(nonnull id<TLRepositoryObject>)subject create:(BOOL)create peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ incomingPeerConnectionWithPeerConnectionId: %@ subject: %@create: %d peerTwincodeOutbound: %@", LOG_TAG, peerConnectionId, subject, create, peerTwincodeOutbound);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLOffer *peerOffer = [self.peerConnectionService getPeerOfferWithPeerConnectionId:peerConnectionId];
    if (!peerOffer) {

        // The peer connection was terminated before we handle it.
        return;
    }

    if (!peerOffer.data) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonNotAuthorized];
        return;
    }
    TLTwincodeOutbound *twincodeOutbound = subject.twincodeOutbound;
    id<TLConversation> conversation = [self getOrCreateConversationWithSubject:subject create:create];
    if (!conversation || !twincodeOutbound) {
        
        // An incoming P2P connection can happen on a group that we left, we must not accept it.
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonRevoked];
        return;
    }

    TLPeerConnectionServiceSdpEncryptionStatus sdpEncryptionStatus = [self.peerConnectionService sdpEncryptionStatusWithPeerConnectionId:peerConnectionId];
    TLConversationImpl *conversationImpl;
    if ([conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        TLGroupConversationImpl *group = (TLGroupConversationImpl *)conversation;
        TLGroupMemberConversationImpl *groupMember = [group getMemberWithTwincodeId:peerTwincodeOutbound.uuid];
        if (groupMember) {
            conversationImpl = groupMember;
            conversation = groupMember;
        } else {
            // If the incoming group member is not known and the session-initiate is encrypted, we cannot proceed
            // because we don't know the secrets to use with that group member.  Reject with GONE to avoid
            // creating the incoming PeerConnection and failing with NO_PRIVATE_KEY.
            if (sdpEncryptionStatus != TLPeerConnectionServiceSdpEncryptionStatusNone) {
                [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGone];
                return;
            }
            conversationImpl = group.incomingConversation;
        }
    } else {
        conversationImpl = (TLConversationImpl *)conversation;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    TLConversationConnection *connection;
    NSUUID *previousIncomingPeerConnectionId = nil;
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    @synchronized(self) {
        connection = [conversationImpl acceptIncomingWithTimestamp:now twinlife:self.twinlife];
        if (connection) {
            previousIncomingPeerConnectionId = [connection startIncomingConversationWithRequestId:requestId peerConnectionId:peerConnectionId now:now];
            // Note: we must store the conversation so that we handle incoming group P2P requests correctly.
            self.peerConnectionId2Conversation[peerConnectionId] = connection;
            DDLogVerbose(@"%@ link P2P %@ to conversation %@", LOG_TAG, peerConnectionId, conversationImpl.uuid);
        }
    }
    
    // Close a previous incoming P2P connection that was not yet opened.
    if (previousIncomingPeerConnectionId) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:previousIncomingPeerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGone];
    }
    
    // Lock the conversation object in the database.  If it is locked, close and return a Busy error.
    if (connection && self.lockIdentifier) {
        int64_t lockTime = [self.serviceProvider lockConversation:conversationImpl lockIdentifier:self.lockIdentifier now:now];
        if (lockTime == 0) {
            connection = nil;
        } else {
            conversationImpl.lastConnectTime = lockTime;
        }
    }
    
    if (!connection) {
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonBusy];
    } else {
        TLOffer *offer = [[TLOffer alloc] initWithAudio:NO video:NO videoBell:NO data:YES];
        TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:NO video:NO data:YES];
        [self.peerConnectionService createIncomingPeerConnectionWithPeerConnectionId:peerConnectionId subject:conversation.subject peerTwincodeOutbound:peerTwincodeOutbound offer:offer offerToReceive:offerToReceive dataChannelDelegate:self delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *uuid) {
            if (errorCode == TLBaseServiceErrorCodeSuccess) {
                @synchronized(self) {
                    connection.incomingState = TLConversationStateOpening;
                }
                [self.scheduler startOperationsWithConnection:connection state:TLConversationStateOpening];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, OPENING_TIMEOUT * NSEC_PER_SEC), self.executorQueue, ^{
                    [self onOpenTimeoutWithConnection:connection requestId:requestId];
                });
            } else {
                @synchronized(self) {
                    [self.peerConnectionId2Conversation removeObjectForKey:peerConnectionId];
                }
                [self closeWithConnection:connection isIncoming:YES peerConnectionId:peerConnectionId terminateReason:[TLPeerConnectionService toTerminateReason:errorCode]];
            }
        }];
    }
}

- (void)updateConversationWithSubject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ updateConversationWithSubject: %@ peerTwincodeOutbound: %@", LOG_TAG, subject, peerTwincodeOutbound);
    
    if (!self.serviceOn) {
        return;
    }

    id<TLConversation> conversation = [self getOrCreateConversationWithSubject:subject create:NO];
    if (!conversation || ![conversation isKindOfClass:[TLConversationImpl class]]) {
        return;
    }

    TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;
    [self.serviceProvider updateConversation:conversationImpl peerTwincodeOutbound:peerTwincodeOutbound];
    [self synchronizeWithConversation:conversationImpl];
}

- (void)synchronizeWithConversation:(nonnull TLConversationImpl *)conversationImpl {
    DDLogVerbose(@"%@ synchronizeWithConversation: %@", LOG_TAG, conversationImpl);

    TLConversationServiceOperation *firstOperation = [self.scheduler getFirstOperationWithConversation:conversationImpl];
    if (!firstOperation || firstOperation.type != TLConversationServiceOperationTypeSynchronizeConversation) {
        TLSynchronizeConversationOperation *synchronizeConversationOperation = [[TLSynchronizeConversationOperation alloc] initWithConversation:conversationImpl];
        [self.serviceProvider storeOperation:synchronizeConversationOperation];
        [self.scheduler addOperation:synchronizeConversationOperation conversation:conversationImpl delay:0.5];
    }
}

- (id<TLConversation>)getConversationWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ getConversationWithSubject: %@", LOG_TAG, subject);
    
    if (!self.serviceOn || !subject) {
        return nil;
    }
    
    return [self.serviceProvider loadConversationWithSubject:subject];
}

- (TLBaseServiceErrorCode)clearConversationWithConversation:(nonnull id<TLConversation>)conversation clearDate:(int64_t)clearDate clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ clearConversationWithConversation: %@ clearDate: %lld clearMode: %d", LOG_TAG, conversation, clearDate, clearMode);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    if (clearDate == 0) {
        clearDate = [[NSDate date] timeIntervalSince1970] * 1000;
    }

    if (clearMode == TLConversationServiceClearBothMedia) {
        int64_t deletedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        NSArray<NSMutableSet<TLDescriptorId *> *> *list = [self.serviceProvider deleteMediaDescriptorsWithConversation:conversation beforeDate:clearDate resetDate:deletedTimestamp];
        NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];

        NSMutableSet<TLDescriptorId *> *deleteList = list[0];
        NSMutableSet<TLDescriptorId *> *ownerDeleteList = list[1];
        NSMutableSet<TLDescriptorId *> *peerDeleteList = list[2];
        if (conversations.count > 0) {
            NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
            
            // Send a delete operation for our own medias to each conversation member.
            if (ownerDeleteList.count > 0) {
                for (TLConversationImpl *conversationImpl in conversations) {
                    [conversationImpl touch];

                    NSMutableArray<TLConversationServiceOperation *> *operations = [[NSMutableArray alloc] init];
                    for (TLDescriptorId *descriptorId in ownerDeleteList) {
                        TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeDelete descriptorId:descriptorId timestamp:deletedTimestamp];
                        [operations addObject:updateDescriptorTimestampOperation];
                    }
                    [pendingOperations setObject:operations forKey:conversationImpl];
                }
            }

            // Send a peer delete operation only to the peer that sent us the media.
            if (peerDeleteList.count > 0) {
                for (TLDescriptorId *descriptorId in peerDeleteList) {
                    for (TLConversationImpl *conversationImpl in conversations) {
                        if ([descriptorId.twincodeOutboundId isEqual:conversationImpl.peerTwincodeOutboundId]) {
                            TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypePeerDelete descriptorId:descriptorId timestamp:deletedTimestamp];
                            NSMutableArray<TLConversationServiceOperation *> *operations = (NSMutableArray<TLConversationServiceOperation *> *)[pendingOperations objectForKey:conversationImpl];
                            if (!operations) {
                                operations = [[NSMutableArray alloc] init];
                                [pendingOperations setObject:operations forKey:conversationImpl];
                            }
                            [operations addObject:updateDescriptorTimestampOperation];
                            [conversationImpl touch];
                            break;
                        }
                    }
                }
            }

            [self addOperationsWithMap:pendingOperations];
        } else if (ownerDeleteList.count > 0) {
            // No member, if we have sent some files, delete them.
            [self deleteFilesWithDescriptors:ownerDeleteList];
        }

        // Cleanup files at the end.
        if (deleteList.count > 0) {
            [self deleteFilesWithDescriptors:deleteList];
        }
        if (peerDeleteList.count > 0) {
            [self deleteFilesWithDescriptors:peerDeleteList];
        }

        if ([conversation isKindOfClass:[TLConversationImpl class]]) {
            TLConversationImpl *conversationImpl = (TLConversationImpl *) conversation;

            int count = [self.serviceProvider countDescriptorsWithConversation:conversationImpl];
            conversationImpl.isActive = count != 0;
        }
 
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onResetConversationWithRequestId:conversation:clearMode:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onResetConversationWithRequestId:TLBaseService.DEFAULT_REQUEST_ID conversation:conversation clearMode:clearMode];
                });
            }
        }

        return TLBaseServiceErrorCodeSuccess;
    }

    NSDictionary<NSUUID *, TLDescriptorId *> *resetList = [self getDescriptorsToDeleteWithConversation:conversation resetDate:clearDate];
    if (resetList.count == 0) {
        return TLBaseServiceErrorCodeSuccess;
    }

    // If the user is not allowed to reset the conversation, switch to local mode.
    if (![conversation hasPermissionWithPermission:TLPermissionTypeResetConversation] && clearMode == TLConversationServiceClearBoth) {
        clearMode = TLConversationServiceClearLocal;
    }

    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    TLClearDescriptor *clearDescriptor;
    if (conversations.count != 0 && clearMode == TLConversationServiceClearBoth) {

        // Create the clear descriptor to tell the peer a reset was made.
        int64_t localCid = 0;
        clearDescriptor = [[TLClearDescriptor alloc] initWithDescriptorId:[[TLDescriptorId alloc] initWithId:0 twincodeOutboundId:conversation.twincodeOutboundId sequenceId:[self newSequenceId]] conversationId:localCid clearTimestamp:clearDate];

    } else {
        clearDescriptor = nil;
    }

    [self resetWithConversation:conversation resetList:resetList clearMode:clearMode];

    if (conversations && conversations.count > 0) {
        NSMutableArray<TLDescriptorId*> *resetMembers = nil;
        
        // For a group, we must send the max sequence that we have removed for each member.
        // This is necessary for protocol version <= 2.12.0.
        if ([conversation isKindOfClass:[TLGroupConversationImpl class]]) {
            resetMembers = [[NSMutableArray alloc] initWithCapacity:conversations.count + 1];
            
            for (NSUUID *twincodeOutboundId in resetList) {
                TLDescriptorId *descriptorId = resetList[twincodeOutboundId];
                if (descriptorId) {
                    [resetMembers addObject:descriptorId];
                }
            }
        }
        
        // Send the reset operation to each peer (sequenceId is used only for protocol <= 2.12.0).
        TLDescriptorId *minDescriptorId = resetList[conversation.twincodeOutboundId];
        int64_t minSequenceId = minDescriptorId == nil ? 0 : minDescriptorId.sequenceId;
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];

            TLDescriptorId *peerDescriptorId = resetList[conversationImpl.peerTwincodeOutboundId];
            int64_t peerMinSequenceId = peerDescriptorId == nil ? 0 : peerDescriptorId.sequenceId;

            TLResetConversationOperation *resetConversationOperation = [[TLResetConversationOperation alloc] initWithConversation:conversationImpl clearDescriptor:clearDescriptor minSequenceId:minSequenceId peerMinSequenceId:peerMinSequenceId resetMembers:resetMembers clearTimestamp:clearDate clearMode:clearMode];
            [self.serviceProvider storeOperation:resetConversationOperation];

            if (clearMode == TLConversationServiceClearBoth) {
                [self.scheduler addOperation:resetConversationOperation conversation:conversationImpl delay:0.0];
            } else {
                [self.scheduler addDeferrableOperation:resetConversationOperation conversation:conversationImpl];
            }
        }
    }

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onResetConversationWithRequestId:conversation:clearMode:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onResetConversationWithRequestId:TLBaseService.DEFAULT_REQUEST_ID conversation:conversation clearMode:clearMode];
            });
        }
    }

    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)deleteConversationWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ deleteConversationWithSubject: %@", LOG_TAG, subject);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }
    
    id <TLConversation> conversation = [self getConversationWithSubject:subject];
    if (!conversation) {
        return TLBaseServiceErrorCodeItemNotFound;
    }
    if ([conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        [self.groupManager deleteGroupConversation:(TLGroupConversationImpl *)conversation];
    } else {
        [self deleteConversation:conversation];
        
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onDeleteConversationWithRequestId:conversationId:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onDeleteConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversationId:conversation.uuid];
                });
            }
        }
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ getDescriptorsWithConversation: %@ callsMode: %u beforeTimestamp: %lld maxObjects: %d", LOG_TAG, conversation, callsMode, beforeTimestamp, maxDescriptors);
    
    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listDescriptorWithConversation:conversation types:nil callsMode:callsMode beforeTimestamp:beforeTimestamp maxDescriptors:maxDescriptors];
}

- (void)getReplyTosWithDescriptors:(nonnull NSArray<TLDescriptor *> *)descriptors {
    DDLogVerbose(@"%@ getReplyTosWithDescriptors: %lu", LOG_TAG, (unsigned long)descriptors.count);
    
    if (!self.serviceOn) {
        return;
    }
    
    NSDictionary<NSNumber *, TLDescriptor *> *replies = [self getNeededRepliesWithDescriptors:descriptors];
    
    if (replies.count > 0){
        NSArray<TLDescriptor *> *replyTos = [self.serviceProvider listDescriptorWithDescriptorIds:replies.allKeys];
        for(TLDescriptor *replyTo in replyTos) {
            TLDescriptor *d = replies[[NSNumber numberWithLongLong:replyTo.descriptorId.id]];
            if (d) {
                d.replyToDescriptor = replyTo;
            }
        }
    }
}

- (nonnull NSDictionary<NSNumber *, TLDescriptor *> *)getNeededRepliesWithDescriptors:(nonnull NSArray<TLDescriptor *> *)descriptors {
    NSMutableDictionary<NSNumber *, TLDescriptor *> *replies = [[NSMutableDictionary alloc] init];
    
    for (TLDescriptor *d in descriptors){
        if (d.replyTo) {
            TLDescriptor *loadedReplyTo = nil;
            for (TLDescriptor *maybeReplyTo in descriptors) {
                if ([d.replyTo isEqual:maybeReplyTo.descriptorId]) {
                    loadedReplyTo = maybeReplyTo;
                    break;
                }
            }
            if (loadedReplyTo) {
                d.replyToDescriptor = loadedReplyTo;
            } else {
                replies[[NSNumber numberWithLongLong:d.replyTo.id]] = d;
            }
        }
    }
    
    return replies;
}

- (NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    
    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listDescriptorWithConversation:conversation types:@[@(descriptorType)] callsMode:callsMode beforeTimestamp:beforeTimestamp maxDescriptors:maxDescriptors];
}

- (NSArray<TLDescriptor *> *)getDescriptorsWithDescriptorType:(TLDescriptorType)descriptorType callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ getDescriptorsWithDescriptorType: %d callsMode: %ud beforeTimestamp: %lld maxObjects: %d", LOG_TAG, descriptorType, callsMode, beforeTimestamp, maxDescriptors);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    return [self.serviceProvider listDescriptorWithConversation:nil types:@[@(descriptorType)] callsMode:callsMode beforeTimestamp:beforeTimestamp maxDescriptors:maxDescriptors];
}

- (nullable NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation types:(nonnull NSArray<NSNumber *> * )types callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ getDescriptorsWithConversation: %@ types: %@ callsMode: %ud beforeTimestamp: %lld maxObjects: %d", LOG_TAG, conversation, types, callsMode, beforeTimestamp, maxDescriptors);
    
    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listDescriptorWithConversation:conversation types:types callsMode:callsMode beforeTimestamp:beforeTimestamp maxDescriptors:maxDescriptors];
}

- (nullable NSSet<NSUUID *> *)getConversationTwincodesWithSubject:(nonnull id<TLRepositoryObject>)subject beforeTimestamp:(int64_t)beforeTimestamp {
    DDLogVerbose(@"%@ getConversationTwincodesWithSubject: %@ beforeTimestamp: %lld", LOG_TAG, subject, beforeTimestamp);

    if (!self.serviceOn) {
        return nil;
    }
    
    id<TLConversation> conversation = [self.serviceProvider loadConversationWithSubject:subject];
    if (!conversation) {
        return nil;
    }

    return [self.serviceProvider listDescriptorTwincodesWithConversation:conversation descriptorType:TLDescriptorTypeDescriptor beforeTimestamp:beforeTimestamp];
}

- (nullable NSSet<NSUUID *> *)getConversationTwincodesWithConversation:(nonnull id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType beforeTimestamp:(int64_t)beforeTimestamp {
    DDLogVerbose(@"%@ getConversationTwincodesWithConversation: %@ descriptorType: %d beforeTimestamp: %lld", LOG_TAG, conversation, descriptorType, beforeTimestamp);

    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listDescriptorTwincodesWithConversation:conversation descriptorType:descriptorType beforeTimestamp:beforeTimestamp];
}

- (nullable NSArray<TLConversationDescriptorPair *> *)getLastConversationDescriptorsWithFilter:(nullable TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode {
    DDLogVerbose(@"%@ getLastConversationDescriptorsWithFilter: %@ callsMode: %u", LOG_TAG, filter, callsMode);

    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listLastConversationDescriptorsWithFilter:filter callsMode:callsMode];
}

- (nullable NSArray<TLConversationDescriptorPair *> *)searchDescriptorsWithConversations:(nonnull NSArray<id<TLConversation>> *)conversations searchText:(nonnull NSString *)searchText beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ searchDescriptorsWithConversations: %@ ", LOG_TAG, searchText);

    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider searchDescriptorsWithConversations:conversations searchText:searchText beforeTimestamp:beforeTimestamp maxDescriptors:maxDescriptors];
}

- (void)pushCommandWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(NSObject *)object {
    DDLogVerbose(@"%@ pushCommandWithRequestId: %lld conversation: %@ object: %@", LOG_TAG, requestId, conversation, object);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLSerializer *serializer = [self.twinlife.serializerFactory getSerializerWithObject:object];
    if (!serializer || ![conversation hasPermissionWithPermission:TLPermissionTypeSendCommand]) {
        TLBaseServiceErrorCode error = (!serializer) ? TLBaseServiceErrorCodeBadRequest : TLBaseServiceErrorCodeNoPermission;
        [self onErrorWithRequestId:requestId errorCode:error errorParameter:nil];
        return;
    }
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    // Create one object descriptor for the conversation.
    TLTransientObjectDescriptor *commandDescriptor = [[TLTransientObjectDescriptor alloc] initWithTwincodeOutboundId:conversation.twincodeOutboundId serializer:serializer object:object];
    
    // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
    if (!conversations || [conversations count] == 0) {
        commandDescriptor.readTimestamp = -1;
        commandDescriptor.sentTimestamp = -1;
        commandDescriptor.receivedTimestamp = -1;
    }
    
    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushCommandOperation *pushCommandOperation = [[TLPushCommandOperation alloc] initWithConversation:conversationImpl commandDescriptor:commandDescriptor];
            [pendingOperations setObject:pushCommandOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:commandDescriptor];
            });
        }
    }
}

- (void)forwardDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo descriptorId:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ forwardDescriptorWithRequestId: %lld conversation: %@ descriptorId: %@ copyAllowed: %d", LOG_TAG, requestId, conversation, descriptorId, copyAllowed);

    if (!self.serviceOn) {
        return;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    if (![conversation hasPermissionWithPermission:[descriptor permission]]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];

        return;
    }

    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:sendTo];
    
    TLDescriptor *forwarded = [self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
        TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];

        // Create one object descriptor for the conversation.
        TLDescriptor *result = [descriptor createForwardWithDescriptorId:did conversationId:cid expireTimeout:expireTimeout sendTo:sendTo copyAllowed:copyAllowed];
        // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
        if (!conversations || [conversations count] == 0) {
            result.readTimestamp = -1;
            result.sentTimestamp = -1;
            result.receivedTimestamp = -1;
        }
        return result;
    }];
    if (!forwarded) {
        // Refuse to forward other descriptors
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }

    if ([descriptor isKindOfClass:[TLFileDescriptor class]]) {
        if (![self copyFileWithDescriptor:(TLFileDescriptor *)descriptor destination:(TLFileDescriptor *)forwarded]) {
            [self.serviceProvider deleteDescriptorWithDescriptorId:forwarded.descriptorId conversation:conversation];
            [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];

            return;
        }
    }

    [self.serviceProvider setAnnotationWithDescriptor:descriptor type:TLDescriptorAnnotationTypeForwarded value:0];
    [self.serviceProvider setAnnotationWithDescriptor:forwarded type:TLDescriptorAnnotationTypeForward value:0];

    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            TLConversationServiceOperation *operation;
            
            if ([forwarded isKindOfClass:[TLObjectDescriptor class]]) {
                operation = [[TLPushObjectOperation alloc] initWithConversation:conversationImpl objectDescriptor:(TLObjectDescriptor *)forwarded];

            } else if ([forwarded isKindOfClass:[TLGeolocationDescriptor class]]) {
                operation = [[TLPushGeolocationOperation alloc] initWithConversation:conversationImpl geolocationDescriptor:(TLGeolocationDescriptor *)forwarded];

            } else if ([forwarded isKindOfClass:[TLFileDescriptor class]]) {
                operation = [[TLPushFileOperation alloc] initWithConversation:conversationImpl fileDescriptor:(TLFileDescriptor *)forwarded];

            } else {
                // Ignore other descriptors
                break;
            }

            [conversationImpl touch];
            conversationImpl.isActive = YES;

            [pendingOperations setObject:operation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:forwarded];
            });
        }
    }
}

- (void)pushObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ pushObjectWithRequestId: %lld conversation: %@ message: %@ copyAllowed: %d", LOG_TAG, requestId, conversation, message, copyAllowed);
    
    if (!self.serviceOn) {
        return;
    }
    
    if (![conversation hasPermissionWithPermission:TLPermissionTypeSendMessage]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }

    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:sendTo];
    TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
        TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];

        // Create one object descriptor for the conversation.
        TLObjectDescriptor *result = [[TLObjectDescriptor alloc] initWithDescriptorId:did conversationId:cid sendTo:sendTo replyTo:replyTo message:message copyAllowed:copyAllowed expireTimeout:expireTimeout];
        // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
        if (!conversations || [conversations count] == 0) {
            result.readTimestamp = -1;
            result.sentTimestamp = -1;
            result.receivedTimestamp = -1;
        }
        return result;
    }];
    if (!objectDescriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }
    
    if (objectDescriptor.replyTo) {
        objectDescriptor.replyToDescriptor = [self getDescriptorWithDescriptorId:objectDescriptor.replyTo];
    }

    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushObjectOperation *pushObjectOperation = [[TLPushObjectOperation alloc] initWithConversation:conversationImpl objectDescriptor:objectDescriptor];
            [pendingOperations setObject:pushObjectOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:objectDescriptor];
            });
        }
    }
}

- (void)updateDescriptorWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId message:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expireTimeout:(nullable NSNumber *)expireTimeout {
    
    if (!self.serviceOn) {
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    // The descriptor must have been sent by the current device.
    if (![descriptor.descriptorId.twincodeOutboundId isEqual:conversation.twincodeOutboundId]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }
    
    int updateFlags;
    if ([descriptor isKindOfClass:[TLObjectDescriptor class]]) {
        TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)descriptor;
        
        if (![objectDescriptor updateWithMessage:message]) {
            message = nil;
        } else {
            [objectDescriptor markEdited];
        }
        if (![objectDescriptor updateWithCopyAllowed:copyAllowed]) {
            copyAllowed = nil;
        }
        if (![objectDescriptor updateWithExpireTimeout:expireTimeout]) {
            expireTimeout = nil;
        }
        updateFlags = [TLUpdateDescriptorOperation buildFlagsWithMessage:message copyAllowed:copyAllowed expireTimeout:expireTimeout];

    } else if ([descriptor isKindOfClass:[TLFileDescriptor class]]) {
        TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)descriptor;
        
        if (![fileDescriptor updateWithCopyAllowed:copyAllowed]) {
            copyAllowed = nil;
        }
        if (![fileDescriptor updateWithExpireTimeout:expireTimeout]) {
            expireTimeout = nil;
        }
        updateFlags = [TLUpdateDescriptorOperation buildFlagsWithMessage:nil copyAllowed:copyAllowed expireTimeout:expireTimeout];

    } else {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }

    if (updateFlags) {
        descriptor.updatedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        [self.serviceProvider updateWithDescriptor:descriptor];

        NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:descriptor.sendTo];
        
        if (conversations && conversations.count > 0) {
            // Send the update to each peer.
            NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
            for (TLConversationImpl *conversationImpl in conversations) {
                [conversationImpl touch];
                conversationImpl.isActive = YES;
                
                TLUpdateDescriptorOperation *updateDescriptorOperation = [[TLUpdateDescriptorOperation alloc] initWithConversation:conversationImpl descriptor:descriptor updateFlags:updateFlags];
                [pendingOperations setObject:updateDescriptorOperation forKey:conversationImpl];
            }
            [self addOperationsWithMap:pendingOperations];
        }
    }
    
    // Notify that the descriptor was updated.
    TLConversationServiceUpdateType updateType = message ? TLConversationServiceUpdateTypeContent : TLConversationServiceUpdateTypeProtection;
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:descriptor updateType:updateType];
            });
        }
    }
}

- (void)pushTransientObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(NSObject *)object {
    DDLogVerbose(@"%@ pushTransientObjectWithRequestId: %lld conversation: %@ object: %@", LOG_TAG, requestId, conversation, object);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLSerializer *serializer = [self.twinlife.serializerFactory getSerializerWithObject:object];
    if (!serializer || ![conversation hasPermissionWithPermission:TLPermissionTypeSendMessage]) {
        TLBaseServiceErrorCode error = (!serializer) ? TLBaseServiceErrorCodeBadRequest : TLBaseServiceErrorCodeNoPermission;
        [self onErrorWithRequestId:requestId errorCode:error errorParameter:nil];
        return;
    }
    
    // Send the transient object to each connected peer: drop the conversations which are not opened.
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    if (conversations) {
        for (NSUInteger i = conversations.count; i > 0; i--) {
            TLConversationImpl *conversationImpl = [conversations objectAtIndex:i - 1];
            TLConversationConnection *connection = conversationImpl.connection;
            
            if (!connection || [connection state] != TLConversationStateOpen) {
                [conversations removeObjectAtIndex:i - 1];
            } else {
                int majorVersion = [connection getMaxPeerMajorVersion];
                int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
                
                if ([serializer isSupportedWithMajorVersion:majorVersion minorVersion:minorVersion]) {
                    [conversationImpl touch];
                } else {
                    [conversations removeObjectAtIndex:i - 1];
                }
            }
        }
    }
    if (!conversations || conversations.count == 0) {
        return;
    }
    
    TLTransientObjectDescriptor *transientObjectDescriptor = [[TLTransientObjectDescriptor alloc] initWithTwincodeOutboundId:conversation.twincodeOutboundId serializer:serializer object:object];
    
    // Send the object to each peer.
    for (TLConversationImpl *conversationImpl in conversations) {
        
        TLPushTransientObjectOperation *pushTransientObjectOperation = [[TLPushTransientObjectOperation alloc] initWithConversation:conversationImpl transientObjectDescriptor:transientObjectDescriptor];
        [self.scheduler addOperation:pushTransientObjectOperation conversation:conversationImpl delay:0.0];
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:transientObjectDescriptor];
            });
        }
    }
}

- (void)pushFileWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ pushFileWithRequestId: %lld conversation: %@ path: %@  type: %u toBeDeleted: %@ copyAllowed: %d", LOG_TAG, requestId, conversation, path, type, toBeDeleted ? @"YES" : @"NO", copyAllowed);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLPermissionType permission;
    switch (type) {
        case TLDescriptorTypeImageDescriptor:
            permission = TLPermissionTypeSendImage;
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            permission = TLPermissionTypeSendAudio;
            break;
            
        case TLDescriptorTypeVideoDescriptor:
            permission = TLPermissionTypeSendVideo;
            break;
            
        default:
            permission = TLPermissionTypeSendFile;
            break;
    }
    if (![conversation hasPermissionWithPermission:permission]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }
    
    // Create one file descriptor for the conversation.
    TLFileDescriptor *fileDescriptor = [self importFileWithConversation:conversation requestId:requestId sendTo:sendTo replyTo:replyTo path:path type:type toBeDeleted:toBeDeleted copyAllowed:copyAllowed expireTimeout:expireTimeout];
    if (!fileDescriptor) {
        return;
    }
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:sendTo];
    
    // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
    if (!conversations || [conversations count] == 0) {
        fileDescriptor.readTimestamp = -1;
        fileDescriptor.sentTimestamp = -1;
        fileDescriptor.receivedTimestamp = -1;
    }

    [self.serviceProvider insertOrUpdateDescriptorWithConversation:conversation descriptor:fileDescriptor];
    
    if (conversations && conversations.count > 0) {
        // Send the file to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushFileOperation *pushFileOperation = [[TLPushFileOperation alloc] initWithConversation:conversationImpl fileDescriptor:fileDescriptor];
            [pendingOperations setObject:pushFileOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push file operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:fileDescriptor];
            });
        }
    }
}

- (void)addOperationsWithMap:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)pendingOperations {
    DDLogVerbose(@"%@ addOperationsWithMap: %@", LOG_TAG, pendingOperations);

    [self.serviceProvider storeOperations:pendingOperations];
    [self.scheduler addOperations:pendingOperations];
}

- (void)pushGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(NSString *)localMapPath expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ pushGeolocationWithRequestId: %lld conversation: %@ longitude: %f latitude: %f altitude: %f mapLongitudeDelta: %f mapLatitudeDelta: %f localMapPath: %@", LOG_TAG, requestId, conversation, longitude, latitude, altitude, mapLongitudeDelta, mapLatitudeDelta, localMapPath);
    
    if (!self.serviceOn) {
        return;
    }
    
    if (![conversation hasPermissionWithPermission:TLPermissionTypeSendGeolocation]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:sendTo];
    
    // Create one object descriptor for the conversation.
    TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
        TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];

        // Create one object descriptor for the conversation.
        TLGeolocationDescriptor *result = [[TLGeolocationDescriptor alloc] initWithDescriptorId:did conversationId:cid sendTo:sendTo replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta expireTimeout:expireTimeout];
        // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
        if (!conversations || [conversations count] == 0) {
            result.readTimestamp = -1;
            result.sentTimestamp = -1;
            result.receivedTimestamp = -1;
        }
        
        if (localMapPath != nil) {
            result.localMapPath = [self saveFileWithDescriptor:result path:localMapPath toBeDeleted:YES];
            result.isValidLocalMap = result.localMapPath != nil;
        }

        return result;
    }];
    if (!geolocationDescriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }

    if (localMapPath != nil) {
        geolocationDescriptor.localMapPath = [self saveFileWithDescriptor:geolocationDescriptor path:localMapPath toBeDeleted:YES];
    }
    
    if (geolocationDescriptor.replyTo) {
        geolocationDescriptor.replyToDescriptor = [self getDescriptorWithDescriptorId:geolocationDescriptor.replyTo];
    }

    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushGeolocationOperation *pushGeolocationOperation = [[TLPushGeolocationOperation alloc] initWithConversation:conversationImpl geolocationDescriptor:geolocationDescriptor];
            [pendingOperations setObject:pushGeolocationOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:geolocationDescriptor];
            });
        }
    }
}

- (void)updateGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(TLDescriptorId *)descriptorId longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(NSString *)localMapPath {
    DDLogVerbose(@"%@ updateGeolocationWithRequestId: %lld conversation: %@ descriptorId: %@ longitude: %f latitude: %f altitude: %f mapLongitudeDelta: %f mapLatitudeDelta: %f localMapPath: %@", LOG_TAG, requestId, conversation, descriptorId, longitude, latitude, altitude, mapLongitudeDelta, mapLatitudeDelta, localMapPath);
    
    if (!self.serviceOn) {
        return;
    }
    
    if (![conversation hasPermissionWithPermission:TLPermissionTypeSendGeolocation]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLGeolocationDescriptor class]] || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)descriptor;
    geolocationDescriptor.longitude = longitude;
    geolocationDescriptor.latitude = latitude;
    geolocationDescriptor.altitude = altitude;
    geolocationDescriptor.mapLongitudeDelta = mapLongitudeDelta;
    geolocationDescriptor.mapLatitudeDelta = mapLatitudeDelta;
    if (localMapPath != nil) {
        geolocationDescriptor.localMapPath = [self saveFileWithDescriptor:geolocationDescriptor path:localMapPath toBeDeleted:YES];
        geolocationDescriptor.isValidLocalMap = geolocationDescriptor.localMapPath != nil;
    } else {
        geolocationDescriptor.isValidLocalMap = NO;
    }
    
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:geolocationDescriptor.sendTo];
    
    // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
    if (!conversations || [conversations count] == 0) {
        geolocationDescriptor.readTimestamp = -1;
        geolocationDescriptor.sentTimestamp = -1;
        geolocationDescriptor.receivedTimestamp = -1;
    }

    [self.serviceProvider updateWithDescriptor:geolocationDescriptor];
    
    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushGeolocationOperation *pushGeolocationOperation = [[TLPushGeolocationOperation alloc] initWithConversation:conversationImpl geolocationDescriptor:geolocationDescriptor];
            [pendingOperations setObject:pushGeolocationOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify update operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:geolocationDescriptor updateType:TLConversationServiceUpdateTypeContent];
            });
        }
    }
}

- (void)saveGeolocationMapWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(TLDescriptorId *)descriptorId path:(NSString *)path {
    DDLogVerbose(@"%@ saveGeolocationMapWithRequestId: %lld conversation: %@ descriptorId: %@ localMapPath: %@", LOG_TAG, requestId, conversation, descriptorId, path);
    
    if (!self.serviceOn) {
        return;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLGeolocationDescriptor class]] || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)descriptor;
    if (path != nil) {
        geolocationDescriptor.localMapPath = [self saveFileWithDescriptor:geolocationDescriptor path:path toBeDeleted:YES];
        geolocationDescriptor.isValidLocalMap = geolocationDescriptor.localMapPath != nil;
    } else {
        geolocationDescriptor.isValidLocalMap = NO;
    }

    [self.serviceProvider updateWithDescriptor:geolocationDescriptor];
    
    // Notify update operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:geolocationDescriptor updateType:TLConversationServiceUpdateTypeContent];
            });
        }
    }
}

- (TLGeolocationDescriptor*)getGeolocationWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ getGeolocationWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLGeolocationDescriptor class]] || descriptor.deletedTimestamp > 0) {
        return nil;
    }
    
    return (TLGeolocationDescriptor *)descriptor;
}

- (void)pushTwincodeWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(NSUUID *)twincodeId schemaId:(NSUUID *)schemaId publicKey:(nullable NSString *)publicKey copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ pushTwincodeWithRequestId: %lld conversation: %@ sendTo: %@ replyTo: %@ twincodeId: %@ schemaId: %@ publicKey: %@ copyAllowed: %d expireTimeout: %lld", LOG_TAG, requestId, conversation, sendTo, replyTo, twincodeId, schemaId, publicKey, copyAllowed, expireTimeout);
    
    if (!self.serviceOn) {
        return;
    }
    
    if (![conversation hasPermissionWithPermission:TLPermissionTypeSendTwincode]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoPermission errorParameter:nil];
        return;
    }
    
    // If we have a group member, keep only the conversation that matches the group member.
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:sendTo];
    TLTwincodeDescriptor *twincodeDescriptor = (TLTwincodeDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
        TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];

        // Create one object descriptor for the conversation.
        TLTwincodeDescriptor *result = [[TLTwincodeDescriptor alloc] initWithDescriptorId:did conversationId:cid sendTo:sendTo replyTo:replyTo twincodeId:twincodeId schemaId:schemaId publicKey:publicKey copyAllowed:copyAllowed expireTimeout:expireTimeout];
        // If we try to send on a group with no peer, mark a send failure (ie, we are the only one in the group!).
        if (!conversations || [conversations count] == 0) {
            result.readTimestamp = -1;
            result.sentTimestamp = -1;
            result.receivedTimestamp = -1;
        }
        return result;
    }];
    if (!twincodeDescriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }

    if (twincodeDescriptor.replyTo) {
        twincodeDescriptor.replyToDescriptor = [self getDescriptorWithDescriptorId:twincodeDescriptor.replyTo];
    }
    
    if (conversations && conversations.count > 0) {
        // Send the object to each peer.
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            conversationImpl.isActive = YES;
            
            TLPushTwincodeOperation *pushTwincodeOperation = [[TLPushTwincodeOperation alloc] initWithConversation:conversationImpl twincodeDescriptor:twincodeDescriptor];
            [pendingOperations setObject:pushTwincodeOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    // Notify push operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:twincodeDescriptor];
            });
        }
    }
}

- (void)acceptPushTwincodeWithSchemaId:(NSUUID *)schemaId {
    DDLogVerbose(@"%@ acceptPushTwincodeWithSchemaId: %@", LOG_TAG, schemaId);
    
    if (!self.serviceOn) {
        return;
    }
    
    [self.acceptedPushTwincode addObject:schemaId];
}

- (void)markDescriptorReadWithRequestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ markDescriptorReadWithRequestId %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    // A call descriptor is local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    [descriptor setReadTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
    [self.serviceProvider updateDescriptorTimestamps:descriptor];
    
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    // Send the descriptor update to the peer that sent us the message.
    if (conversations && conversations.count > 0) {
        NSUUID *twincodeOutboundId = descriptorId.twincodeOutboundId;
        for (TLConversationImpl *conversationImpl in conversations) {
            if (![conversation isGroup] || [twincodeOutboundId isEqual:conversationImpl.peerTwincodeOutboundId]) {
                [conversationImpl touch];
                
                TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeRead descriptorId:descriptorId timestamp:descriptor.readTimestamp];
                [self.serviceProvider storeOperation:updateDescriptorTimestampOperation];
                if (descriptor.expireTimeout > 0) {
                    [self.scheduler addOperation:updateDescriptorTimestampOperation conversation:conversationImpl delay:0.0];
                } else {
                    [self.scheduler addDeferrableOperation:updateDescriptorTimestampOperation conversation:conversationImpl];
                }
                break;
            }
        }
    }
    
    // Notify descriptor update operation was queued.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onMarkDescriptorReadWithRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onMarkDescriptorReadWithRequestId:requestId conversation:conversation descriptor:descriptor];
            });
        }
    }
}

- (void)markDescriptorDeletedWithRequestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ markDescriptorDeletedWithRequestId %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    // A call descriptor must be deleted immediately: it is local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor) {
        [descriptor setDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
        [descriptor setPeerDeletedTimestamp:descriptor.deletedTimestamp];
        [self deleteConversationDescriptor:descriptor requestId:requestId conversation:conversation];

        return;
    }
    
    // If this is an invitation, we need some specific cleaning and we do the withdraw invitation process.
    BOOL needPeerUpdate;
    if ([descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        [self withdrawInviteGroupWithRequestId:requestId invitation:(TLInvitationDescriptor *)descriptor];
        needPeerUpdate = false;
    } else {
        needPeerUpdate = descriptor.sentTimestamp > 0;

        // If the peer has deleted the descriptor, we can delete it immediately.
        if (descriptor.peerDeletedTimestamp > 0 && ![conversation isGroup]) {
            needPeerUpdate = NO;
        }

        // Update the deleted timestamp the first time it is deleted (the user can perform the action several times).
        if (descriptor.deletedTimestamp == 0) {
            [descriptor setDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
            if (!needPeerUpdate && descriptor.peerDeletedTimestamp == 0) {
                [descriptor setPeerDeletedTimestamp:descriptor.deletedTimestamp];
            }
            [self.serviceProvider updateDescriptorTimestamps:descriptor];
        }
    }

    if (needPeerUpdate) {
        NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:descriptor.sendTo];
        
        // Send the delete descriptor to each peer.
        if (conversations && conversations.count > 0) {
            NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
            for (TLConversationImpl *conversationImpl in conversations) {
                
                TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeDelete descriptorId:descriptorId timestamp:descriptor.deletedTimestamp];
                [pendingOperations setObject:updateDescriptorTimestampOperation forKey:conversationImpl];
            }
            [self addOperationsWithMap:pendingOperations];
        }

        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onMarkDescriptorDeletedWithRequestId:conversation:descriptor:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onMarkDescriptorDeletedWithRequestId:requestId conversation:conversation descriptor:descriptor];
                });
            }
        }
        
    } else {
        [self deleteConversationDescriptor:descriptor requestId:requestId conversation:conversation];
    }
}

- (TLBaseServiceErrorCode)setAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ setAnnotationWithDescriptorId: %@ type: %d value: %d", LOG_TAG, descriptorId, type, value);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    // The FORWARD and FORWARDED are annotations managed internally.
    if (type == TLDescriptorAnnotationTypeForward || type == TLDescriptorAnnotationTypeForwarded) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        return TLBaseServiceErrorCodeItemNotFound;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    // The Call and Clear descriptors are local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor || [descriptor getType] == TLDescriptorTypeClearDescriptor) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    BOOL modified = [self.serviceProvider setAnnotationWithDescriptor:descriptor type:type value:value];
    if (!modified) {
        return TLBaseServiceErrorCodeSuccess;
    }

    // Something was modified on the descriptor, prepare to send an UpdateAnnotationsIQ.
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    if (conversations && conversations.count > 0) {
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            TLUpdateAnnotationsOperation *updateAnnotationsOperation = [[TLUpdateAnnotationsOperation alloc] initWithConversation:conversationImpl descriptorId:descriptorId];

            [pendingOperations setObject:updateAnnotationsOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor updateType:TLConversationServiceUpdateTypeLocalAnnotations];
            });
        }
    }

    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)deleteAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type {
    DDLogVerbose(@"%@ deleteAnnotationWithDescriptorId: %@ type: %d", LOG_TAG, descriptorId, type);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    // The FORWARD and FORWARDED are annotations managed internally.
    if (type == TLDescriptorAnnotationTypeForward || type == TLDescriptorAnnotationTypeForwarded) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        return TLBaseServiceErrorCodeItemNotFound;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    // The Call and Clear descriptors are local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor || [descriptor getType] == TLDescriptorTypeClearDescriptor) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    BOOL modified = [self.serviceProvider deleteAnnotationWithDescriptor:descriptor type:type];
    if (!modified) {
        return TLBaseServiceErrorCodeSuccess;
    }

    // Something was modified on the descriptor, prepare to send an UpdateAnnotationsIQ.
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    if (conversations && conversations.count > 0) {
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            TLUpdateAnnotationsOperation *updateAnnotationsOperation = [[TLUpdateAnnotationsOperation alloc] initWithConversation:conversationImpl descriptorId:descriptorId];

            [pendingOperations setObject:updateAnnotationsOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor updateType:TLConversationServiceUpdateTypeLocalAnnotations];
            });
        }
    }

    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)toggleAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ toggleAnnotationWithDescriptorId: %@ type: %d value: %d", LOG_TAG, descriptorId, type, value);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    // The FORWARD and FORWARDED are annotations managed internally.
    if (type == TLDescriptorAnnotationTypeForward || type == TLDescriptorAnnotationTypeForwarded) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        return TLBaseServiceErrorCodeItemNotFound;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    // The Call and Clear descriptors are local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor || [descriptor getType] == TLDescriptorTypeClearDescriptor) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    BOOL modified = [self.serviceProvider toggleAnnotationWithDescriptor:descriptor type:type value:value];
    if (!modified) {
        return TLBaseServiceErrorCodeSuccess;
    }

    // Something was modified on the descriptor, prepare to send an UpdateAnnotationsIQ.
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:conversation sendTo:nil];
    
    if (conversations && conversations.count > 0) {
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            TLUpdateAnnotationsOperation *updateAnnotationsOperation = [[TLUpdateAnnotationsOperation alloc] initWithConversation:conversationImpl descriptorId:descriptorId];

            [pendingOperations setObject:updateAnnotationsOperation forKey:conversationImpl];
        }
        [self addOperationsWithMap:pendingOperations];
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor updateType:TLConversationServiceUpdateTypeLocalAnnotations];
            });
        }
    }

    return TLBaseServiceErrorCodeSuccess;
}

- (nullable NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair *> *)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ listAnnotationsWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider listAnnotationsWithDescriptorId:descriptorId];
}

- (void)deleteDescriptorWithRequestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ deleteDescriptorWithRequestId %lld descriptorId: %@", LOG_TAG, requestId, descriptorId);
    
    if (!self.serviceOn) {
        return;
    }

    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    // A call descriptor must be deleted immediately: it is local only.
    if ([descriptor getType] == TLDescriptorTypeCallDescriptor) {
        [descriptor setDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
        [descriptor setPeerDeletedTimestamp:descriptor.deletedTimestamp];
        [self deleteConversationDescriptor:descriptor requestId:requestId conversation:conversation];

        return;
    }
    
    // Send the PEER_DELETE update to the peer that sent us the message.
    if (descriptor.deletedTimestamp == 0) {
        NSMutableArray *conversations = [TLConversationService getConversations:conversation sendTo:nil];
        if (conversations && conversations.count > 0) {
            NSUUID *twincodeOutboundId = descriptorId.twincodeOutboundId;
            for (TLConversationImpl *conversationImpl in conversations) {
                if (![conversation isGroup] || [twincodeOutboundId isEqual:conversationImpl.peerTwincodeOutboundId]) {
                    [conversationImpl touch];
                
                    TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypePeerDelete descriptorId:descriptorId timestamp:[[NSDate date] timeIntervalSince1970] * 1000];
                    [self.serviceProvider storeOperation:updateDescriptorTimestampOperation];
                    if (descriptor.expireTimeout > 0) {
                        [self.scheduler addOperation:updateDescriptorTimestampOperation conversation:conversationImpl delay:0.0];
                    } else {
                        [self.scheduler addDeferrableOperation:updateDescriptorTimestampOperation conversation:conversationImpl];
                    }
                }
            }
        }
    }

    [self deleteConversationDescriptor:descriptor requestId:requestId conversation:conversation];
}

#pragma mark - TLConversationService - Group

- (nullable id<TLGroupConversation>)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject owner:(BOOL)owner {
    DDLogVerbose(@"%@ createGroupConversationWithSubject: %@ owner: %d", LOG_TAG, subject, owner);
    
    return [self.groupManager createGroupConversationWithSubject:subject owner:owner];
}

- (TLBaseServiceErrorCode)inviteGroupWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation group:(nonnull id<TLRepositoryObject>)group name:(NSString *)name {
    DDLogVerbose(@"%@ inviteGroupWithRequestId %lld conversation: %@ group: %@ name: %@", LOG_TAG, requestId, conversation, group, name);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager inviteGroupWithRequestId:requestId conversation:conversation group:group name:name];
}

- (TLBaseServiceErrorCode)withdrawInviteGroupWithRequestId:(int64_t)requestId invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ withdrawInviteGroupWithRequestId %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager withdrawInviteGroupWithRequestId:requestId invitation:invitation];
}

- (TLBaseServiceErrorCode)joinGroupWithRequestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId group:(nullable id<TLRepositoryObject>)group {
    DDLogVerbose(@"%@ joinGroupWithRequestId %lld descriptorId: %@ group: %@", LOG_TAG, requestId, descriptorId, group);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager joinGroupWithRequestId:requestId descriptorId:descriptorId group:group];
}

- (TLBaseServiceErrorCode)registeredGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group adminTwincodeOutbound:(nonnull TLTwincodeOutbound *)adminTwincodeOutbound adminPermissions:(long)adminPermissions permissions:(long)permissions {
    DDLogVerbose(@"%@ registeredGroupWithRequestId %lld group: %@ adminTwincodeOutbound: %@ adminPermissions: %ld permissions: %ld", LOG_TAG, requestId, group, adminTwincodeOutbound, adminPermissions, permissions);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager registeredGroupWithRequestId:requestId group:group adminTwincodeOutbound:adminTwincodeOutbound adminPermissions:adminPermissions permissions:permissions];
}

- (TLBaseServiceErrorCode)leaveGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group memberTwincodeId:(NSUUID*)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithRequestId %lld group: %@ memberTwincodeId: %@", LOG_TAG, requestId, group, memberTwincodeId);
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager leaveGroupWithRequestId:requestId group:group memberTwincodeId:memberTwincodeId];
}

- (nonnull NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *)listPendingInvitationsWithGroup:(nonnull id<TLRepositoryObject>)group {
    DDLogVerbose(@"%@ listPendingInvitationsWithGroup: %@", LOG_TAG, group);
    
    return [self.serviceProvider listPendingInvitationsWithGroup:group];
}

- (TLInvitationDescriptor*)getInvitationWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ getInvitationWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    // Retrieve the descriptor for the invitation.
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        return nil;
    }
    return (TLInvitationDescriptor *)descriptor;
}

- (TLTwincodeDescriptor*)getTwincodeWithDescriptorId:(TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ getTwincodeWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLTwincodeDescriptor class]]) {
        return nil;
    }
    if (descriptor.deletedTimestamp > 0) {
        return nil;
    }
    
    return (TLTwincodeDescriptor *)descriptor;
}

- (nullable TLDescriptor*)getDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ getDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        return nil;
    }

    return descriptor;
}

- (TLBaseServiceErrorCode)setPermissionsWithSubject:(nullable id<TLRepositoryObject>)group memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    
    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    return [self.groupManager setPermissionsWithSubject:group memberTwincodeId:memberTwincodeId permissions:permissions];
}

#pragma mark - TLConversationService - Calls

- (void)startCallWithRequestId:(int64_t)requestId subject:(nonnull id<TLRepositoryObject>)subject video:(BOOL)video incomingCall:(BOOL)incomingCall {
    DDLogVerbose(@"%@ startCallWithRequestId: %lld subject: %@ video: %d incomingCall: %d", LOG_TAG, requestId, subject, video, incomingCall);
    
    if (!self.serviceOn) {
        return;
    }
    
    id<TLConversation> conversation = [self getOrCreateConversationWithSubject:subject create:YES];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }

    TLCallDescriptor *callDescriptor = (TLCallDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
        TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];

        // Create one object descriptor for the conversation.
        TLCallDescriptor *result = [[TLCallDescriptor alloc] initWithDescriptorId:did conversationId:cid video:video  incomingCall:incomingCall];
        return result;
    }];
    if (!callDescriptor) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }

    if (incomingCall) {
        // Similar to the reception of a message/file, call onPopDescriptor() when we receive a call.
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onPopDescriptorWithRequestId:requestId conversation:conversation descriptor:callDescriptor];
                });
            }
        }
    } else {
        // And call onPushDescriptor() when we are the initiator of the call.
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onPushDescriptorRequestId:requestId conversation:conversation descriptor:callDescriptor];
                });
            }
        }
    }
}

- (void)acceptCallWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId descriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ acceptCallWithRequestId: %lld twincodeOutboundId: %@ descriptorId: %@", LOG_TAG, requestId, twincodeOutboundId, descriptorId);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLCallDescriptor class]] || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    TLCallDescriptor *callDescriptor = (TLCallDescriptor *)descriptor;
    
    [callDescriptor setAccepted];
    [self.serviceProvider updateWithDescriptor:callDescriptor];
    
    // Notify that the call descriptor timestamps was updated.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:callDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
            });
        }
    }
}

- (void)terminateCallWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId descriptorId:(nonnull TLDescriptorId *)descriptorId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ terminateCallWithRequestId: %lld twincodeOutboundId: %@ descriptorId: %@ terminateReason: %d", LOG_TAG, requestId, twincodeOutboundId, descriptorId, terminateReason);
    
    if (!self.serviceOn) {
        return;
    }
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLCallDescriptor class]] || descriptor.deletedTimestamp > 0) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:nil];
        return;
    }

    TLCallDescriptor *callDescriptor = (TLCallDescriptor *)descriptor;
    
    [callDescriptor setTerminateReason:terminateReason];
    [self.serviceProvider updateWithDescriptor:callDescriptor];
    
    // Notify that the call descriptor timestamps was updated.
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:callDescriptor updateType:TLConversationServiceUpdateTypeContent];
            });
        }
    }
}

#pragma mark - PeerConnectionDelegate

- (void)onAcceptPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer {
    
}

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state {
    
}

- (void)onTerminatePeerConnectionWithPeerConnectionId:(NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ onTerminatePeerConnectionWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
    
    [self closeWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
}

- (void)onAddLocalAudioTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender audioTrack:(nonnull RTC_OBJC_TYPE(RTCAudioTrack) *)audioTrack {
    
}

- (void)onAddRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId mediaTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)mediaTrack {
    
}

- (void)onRemoveLocalSenderWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender {
    
}

- (void)onRemoveRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId trackId:(nonnull NSString *)trackId {
    
}

- (void)onPeerHoldCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    //NOOP
}

- (void)onPeerResumeCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    //NOOP
}


#pragma mark - PeerDataChannelDelegate

- (nonnull TLPeerConnectionDataChannelConfiguration *)configurationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sdpEncryptionStatus:(TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus {
    DDLogVerbose(@"%@ configurationWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    return [[TLPeerConnectionDataChannelConfiguration alloc] initWithVersion:TLConversationService.VERSION leadingPadding:sdpEncryptionStatus == TLPeerConnectionServiceSdpEncryptionStatusNone];
}

- (void)onDataChannelOpenWithPeerConnectionId:(NSUUID *)peerConnectionId peerVersion:(NSString *)peerVersion leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelOpenWithPeerConnectionId: %@ peerVersion: %@", LOG_TAG, peerConnectionId, peerVersion);
    
    TLConversationConnection *connection;
    @synchronized(self) {
        connection = self.peerConnectionId2Conversation[peerConnectionId];
    }
    if (!connection) {
        DDLogVerbose(@"%@ missing link for P2P %@", LOG_TAG, peerConnectionId);
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGone];
        return;
    }

    [connection setPeerVersion:peerVersion];
    connection.withLeadingPadding = leadingPadding;
    BOOL open = NO;
    @synchronized(self) {
        open = [connection readyForConversationWithPeerConnectionId:peerConnectionId];
    }
    if (open) {
        TLConversationImpl *conversationImpl = connection.conversation;
        if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
            NSUUID *resourceId = conversationImpl.resourceId;

            // Until we receive the peer device state, do as if it has some pending operations.
            connection.peerDeviceState = DEVICE_STATE_HAS_OPERATIONS;

            TLSynchronizeIQ *synchronizeIQ = [[TLSynchronizeIQ alloc] initWithSerializer:[TLSynchronizeIQ SERIALIZER_1] requestId:[TLTwinlife newRequestId] twincodeOutboundId:conversationImpl.twincodeOutboundId resourceId:resourceId timestamp:now];
            [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetSynchronize iq:synchronizeIQ];
            
            connection.synchronizeKeys = [self checkPublicKeyWithPeerConnectionId:peerConnectionId connection:connection];
        } else {
            TLConversationServiceOperation *firstOperation = [self.scheduler startOperationsWithConnection:connection state:TLConversationStateOpen];
            if (firstOperation) {
                [self sendOperationInternalWithConnection:connection operation:firstOperation];
            }
        }
    } else {
        [self closeWithConnection:connection terminateReason:TLPeerConnectionServiceTerminateReasonGone];
    }
}

- (BOOL)checkPublicKeyWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId connection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ checkAndCreateKeysWithPeerConnectionId: %@ connection: %@", LOG_TAG, peerConnectionId, connection);

    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_18]) {
        TLConversationImpl *conversationImpl = connection.conversation;
        TLTwincodeOutbound *twincodeOutbound = conversationImpl.subject.twincodeOutbound;
        TLTwincodeInbound *twincodeInbound = conversationImpl.subject.twincodeInbound;
        TLTwincodeOutbound *peerTwincodeOutbound = conversationImpl.peerTwincodeOutbound;

        // The 3 twincodes must be valid AND we must ignore the special case where
        // twincodeOutbound == peerTwincodeOutbound which could occur for a group member conversation
        // iff the member is not immediately recognized.
        if (twincodeOutbound && twincodeInbound && peerTwincodeOutbound && twincodeOutbound != peerTwincodeOutbound) {
            if (!twincodeOutbound.isSigned) {
                [self createAndSendPublicKeyWithPeerConnectionId:peerConnectionId conversation:conversationImpl twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound peerTwincode:peerTwincodeOutbound];
                return YES;
            } else {
                TLPeerConnectionServiceSdpEncryptionStatus sdpEncryptionStatus = [self.peerConnectionService sdpEncryptionStatusWithPeerConnectionId:peerConnectionId];
                if (sdpEncryptionStatus != TLPeerConnectionServiceSdpEncryptionStatusEncrypted) {
                    TLSignatureInfoIQ *iq = [self.twinlife.getCryptoService getSignatureInfoIQWithTwincode:twincodeOutbound peerTwincode:peerTwincodeOutbound renew:sdpEncryptionStatus != TLPeerConnectionServiceSdpEncryptionStatusNone];
                    
                    if (!iq) {
                        return NO;
                    }
                    
                    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetSignatureInfo iq:iq];
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)createAndSendPublicKeyWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId conversation:(nonnull TLConversationImpl *)conversation twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode {
    DDLogVerbose(@"%@ createAndSendPublicKeyWithPeerConnectionId: peerConnectionId= %@ twincodeInbound= %@ twincodeOutbound=%@ peerTwincode: %@", LOG_TAG, peerConnectionId, twincodeInbound, twincodeOutbound, peerTwincode);
    
    [self.twinlife.getTwincodeOutboundService createPrivateKeyWithTwincode:twincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound * _Nullable signedTwincode) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !signedTwincode) {
            DDLogVerbose(@"%@ Could not create private key for twincode %@ : %d", LOG_TAG, twincodeOutbound, errorCode);
            return;
        }
        
        if (!signedTwincode.isSigned || ![signedTwincode.uuid isEqual:twincodeOutbound.uuid]) {
            DDLogVerbose(@"%@ Invalid signed twincode %@ : %d", LOG_TAG, signedTwincode, errorCode);
            return;
        }
        
        TLSignatureInfoIQ *iq = [self.twinlife.getCryptoService getSignatureInfoIQWithTwincode:twincodeOutbound peerTwincode:peerTwincode renew:NO];
        
        if (!iq) {
            return;
        }
        
        [self.peerConnectionService sendPacketWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqSetSignatureInfo iq:iq];
    }];
}

- (void)onDataChannelClosedWithPeerConnectionId:(NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onDataChannelClosedWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);
    
}

- (void)onDataChannelMessageWithPeerConnectionId:(NSUUID *)peerConnectionId data:(NSData *)data leadingPadding:(BOOL)leadingPadding {
    DDLogVerbose(@"%@ onDataChannelMessageWithPeerConnectionId: %@ data: %@", LOG_TAG, peerConnectionId, data);

    NSException *exception;
    TLIQ *iq = nil;
    TLIQ *unknownIQ = nil;
    NSUUID *schemaId = nil;
    int schemaVersion = -1;
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
        TLPeerConnectionPacketHandler *listener = self.binaryPacketListeners[key];
        if (listener) {
            TLBinaryPacketIQ *bIq = (TLBinaryPacketIQ *)[listener.serializer deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];

            [self.peerConnectionService incrementStatWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];
            TLConversationConnection *connection = [self preparePeerConversationWithPeerConnectionId:peerConnectionId peerTwincodeOutboundId:nil peerResourceId:nil];
            if (!connection) {
                return;
            }

            dispatch_async(self.executorQueue, ^{
                @try {
                    listener.listener(connection, bIq);
                } @catch(NSException *lException) {
                    [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint EXCEPTION] exception:lException, [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithSchemaId:schemaId], [TLAssertValue initWithSchemaVersion:schemaVersion], [TLAssertValue initWithLine:__LINE__], nil];
                }
            });
            return;
        }

        if ([TLSynchronizeIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLSynchronizeIQ.SCHEMA_VERSION_1 == schemaVersion) {
                TLSynchronizeIQ *bIq = (TLSynchronizeIQ *)[[TLSynchronizeIQ SERIALIZER_1] deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];

                [self processSynchronizeIQWithPeerConnectionId:peerConnectionId iq:bIq];
                return;
            }
        }
        if ([TLResetConversationIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceResetConversationIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceResetConversationIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            } else if (schemaVersion < TLConversationServiceResetConversationIQ.SCHEMA_VERSION) {
                // Reject very old versions properly.
                iq = unknownIQ = (TLIQ *)[TLServiceRequestIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnResetConversationIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnResetConversationIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnResetConversationIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            } else if (schemaVersion < TLConversationServiceOnResetConversationIQ.SCHEMA_VERSION) {
                // Reject very old versions properly.
                iq = unknownIQ = (TLIQ *)[TLServiceRequestIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushObjectIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushObjectIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushObjectIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            } else if (schemaVersion < TLConversationServicePushObjectIQ.SCHEMA_VERSION) {
                // Reject very old versions properly.
                iq = unknownIQ = (TLIQ *)[TLServiceRequestIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushObjectIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushObjectIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushObjectIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushTransientIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushTransientObjectIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushTransientObjectIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            } else {
                return; // Ignore very old version of PushTransient message.
            }
            
        } else if ([TLPushFileIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushFileIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushFileIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            } else if (schemaVersion < TLConversationServicePushFileIQ.SCHEMA_VERSION) {
                // Reject very old versions properly.
                iq = unknownIQ = (TLIQ *)[TLServiceRequestIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushFileIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushFileIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushFileIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushFileChunkIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushFileChunkIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushFileChunkIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushFileChunkIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushFileChunkIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushFileChunkIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLUpdateTimestampIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLUpdateDescriptorTimestampIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLUpdateDescriptorTimestampIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnUpdateTimestampIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLOnUpdateDescriptorTimestampIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLOnUpdateDescriptorTimestampIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLInviteGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceInviteGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceInviteGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLConversationServiceRevokeInviteGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceRevokeInviteGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceRevokeInviteGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLJoinGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceJoinGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceJoinGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLConversationServiceLeaveGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceLeaveGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceLeaveGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLUpdatePermissionsIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceUpdateGroupMemberIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceUpdateGroupMemberIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnInviteGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnResultGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnResultGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnJoinGroupIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnResultJoinGroupIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnResultJoinGroupIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushGeolocationIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushGeolocationIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushGeolocationIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushGeolocationIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushGeolocationIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushGeolocationIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushTwincodeIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushTwincodeIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushTwincodeIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushTwincodeIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushTwincodeIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushTwincodeIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLPushCommandIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServicePushCommandIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServicePushCommandIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLOnPushCommandIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLConversationServiceOnPushCommandIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLConversationServiceOnPushCommandIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }

        } else if ([TLServiceErrorIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLServiceErrorIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLServiceErrorIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
            
        } else if ([TLErrorIQ.SCHEMA_ID isEqual:schemaId]) {
            if (TLErrorIQ.SCHEMA_VERSION == schemaVersion) {
                iq = (TLIQ *)[TLErrorIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
            }
        } else {
            iq = unknownIQ = (TLIQ *)[TLServiceRequestIQ.SERIALIZER deserializeWithSerializerFactory:self.twinlife.serializerFactory decoder:binaryDecoder];
        }
    }
    @catch(NSException *lException) {
        exception = lException;
    }
    
    if (!iq) {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint EXCEPTION] exception:exception, [TLAssertValue initWithSchemaId:schemaId], [TLAssertValue initWithSchemaVersion:schemaVersion], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
        return;
    }
    
    NSString *from = iq.from;
    NSArray *items = [from componentsSeparatedByString:@"/"];
    NSUUID *resourceId = nil;
    NSUUID *peerTwincodeOutboundId = nil;
    if (items.count == 2) {
        resourceId = [[NSUUID alloc] initWithUUIDString:items[1]];
        peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:items[0]];
    }

    TLConversationConnection *connection = [self preparePeerConversationWithPeerConnectionId:peerConnectionId peerTwincodeOutboundId:peerTwincodeOutboundId peerResourceId:resourceId];
    [connection touch];

    // Handle unknown IQ here: try to reply with a service error.
    if (unknownIQ) {
        TLErrorIQ *errorIQ;
        if ([unknownIQ isKindOfClass:[TLServiceRequestIQ class]]) {
            TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)unknownIQ;
            errorIQ = [[TLServiceErrorIQ alloc] initWithId:serviceRequestIQ.id from:connection.from to:connection.to errorType:TLErrorIQTypeCancel condition:TL_ERROR_IQ_FEATURE_NOT_IMPLEMENTED requestSchemaId:schemaId requestSchemaVersion:schemaVersion requestId:serviceRequestIQ.requestId service:serviceRequestIQ.service action:serviceRequestIQ.action majorVersion:serviceRequestIQ.majorVersion minorVersion:serviceRequestIQ.minorVersion];
        } else {
            errorIQ = [[TLErrorIQ alloc] initWithId:unknownIQ.id from:connection.from to:connection.to errorType:TLErrorIQTypeCancel condition:TL_ERROR_IQ_FEATURE_NOT_IMPLEMENTED requestSchemaId:schemaId requestSchemaVersion:schemaVersion];
        }
        [self sendErrorIQWithConnection:connection errorIQ:errorIQ];
        return;
    }

    dispatch_async(self.executorQueue, ^{
        [self processIQWithConnection:connection schemaId:schemaId schemaVersion:schemaVersion iq:iq];
    });
}

#pragma mark - Conversation methods

+ (nonnull NSMutableArray<TLConversationImpl *> *)getConversations:(nonnull id <TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo {
    
    if ([conversation isKindOfClass:[TLConversationImpl class]]) {
        return [NSMutableArray arrayWithObject:conversation];

    } else if ([conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
        
        return [groupConversation getConversations:sendTo];
    } else {
        return [[NSMutableArray alloc] init];
    }
}

- (int64_t)newSequenceId {
    DDLogVerbose(@"%@ newSequenceId", LOG_TAG);
    
    return [self.serviceProvider newSequenceId];
}

- (void)loadConversations {
    DDLogVerbose(@"%@ loadConversations", LOG_TAG);
    
    dispatch_async(self.executorQueue, ^{
        // [self getConversations];
        if (self.needResyncGroups) {
            self.needResyncGroups = NO;
            [self resyncGroups];
        }
    });
}

- (nonnull NSMutableArray<id<TLConversation>> *)listConversationsWithFilter:(nullable TLFilter *)filter {
    DDLogVerbose(@"%@ listConversationsWithFilter: %@", LOG_TAG, filter);

    return [self.serviceProvider listConversationsWithFilter:filter];
}

- (id <TLConversation>)getConversationWithId:(nonnull TLDatabaseIdentifier *)conversationId {
    DDLogVerbose(@"%@ getConversationWithId: %@", LOG_TAG, conversationId);
    
    return [self.serviceProvider loadConversationWithId:conversationId.identifier];
}

- (id<TLGroupConversation>)getGroupConversationWithGroupTwincodeId:(NSUUID *)groupTwincodeId {
    DDLogVerbose(@"%@ getGroupConversationWithGroupTwincodeId: groupTwincodeId: %@", LOG_TAG, groupTwincodeId);
    
    if (!groupTwincodeId) {
        return nil;
    }

    return [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
}

- (nullable id<TLGroupMemberConversation>)getGroupMemberConversationWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ getGroupConversationWithGroupTwincodeId: groupTwincodeId: %@", LOG_TAG, groupTwincodeId);
    
    if (!groupTwincodeId) {
        return nil;
    }

    id<TLGroupConversation> groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return nil;
    }
    
    TLGroupConversationImpl *groupConversationImpl = (TLGroupConversationImpl *)groupConversation;
    return [groupConversationImpl getMemberWithTwincodeId:memberTwincodeId];
}

- (nullable id <TLConversation>)getOrCreateConversationWithSubject:(nonnull id<TLRepositoryObject>)subject create:(BOOL)create {
    DDLogVerbose(@"%@ getOrCreateConversationWithSubject: %@ create: %d", LOG_TAG, subject, create);

    id<TLConversation> conversation = [self.serviceProvider loadConversationWithSubject:subject];
    if (conversation || !create) {
        return conversation;
    }

    conversation = [self.serviceProvider createConversationWithSubject:subject];
    if (conversation) {
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onGetOrCreateConversationWithRequestId:conversation:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onGetOrCreateConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation];
                });
            }
        }
    }
    return conversation;
}

- (nonnull NSDictionary<NSUUID *, TLDescriptorId *> *)getDescriptorsToDeleteWithConversation:(nonnull id<TLConversation>)conversation resetDate:(int64_t)resetDate {
    DDLogVerbose(@"%@ getDescriptorsToDeleteWithConversation: %@ resetDate: %lld", LOG_TAG, conversation, resetDate);

    return [self.serviceProvider listDescriptorsToDeleteWithConversation:conversation twincodeOutboundId:nil resetDate:resetDate];
}

- (BOOL)resetWithConversation:(id<TLConversation>)conversation resetList:(NSDictionary<NSUUID *, TLDescriptorId *> *)resetList clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogVerbose(@"%@ resetWithConversation: %@ resetList: %@ clearMode: %d", LOG_TAG, conversation, resetList, clearMode);

    if ([conversation isKindOfClass:[TLConversationImpl class]]) {
        TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;

        // Step 2: remove the files associated with descriptors.
        [self deleteUnreacheableFilesWithConversation:conversation resetList:resetList clearMode:clearMode];

        // Step 3: now, it is safe to delete the descriptors from the DB.
        NSMutableArray<NSNumber *> *deletedOperations = [[NSMutableArray alloc] init];
        BOOL result = [self.serviceProvider deleteDescriptorsWithMap:resetList conversation:conversation keepMediaMessages:clearMode == TLConversationServiceClearMedia deletedOperations:deletedOperations];

        // Step 4: remove the pending operations for the descriptors that are deleted.
        if (deletedOperations.count > 0) {
            [self.scheduler removeOperationsWithConversation:conversationImpl deletedOperations:deletedOperations];
        }

        // Step 5: check if we still have some descriptor for this conversation.
        int count = [self.serviceProvider countDescriptorsWithConversation:conversationImpl];
        conversationImpl.isActive = count != 0;
 
        return result;

    } else {

        // Step 4: remove the files associated with descriptors.
        [self deleteUnreacheableFilesWithConversation:conversation resetList:resetList clearMode:clearMode];

        // Step 5: now, it is safe to delete the descriptors from the DB.
        NSMutableArray<NSNumber *> *deletedOperations = [[NSMutableArray alloc] init];
        return [self.serviceProvider deleteDescriptorsWithMap:resetList conversation:conversation keepMediaMessages:clearMode == TLConversationServiceClearMedia deletedOperations:deletedOperations];
    }
}

- (void)connectWithConversation:(TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ connectWithConversation: %@", LOG_TAG, conversation);

    // If we are suspending or suspended, don't open a new P2P connection.
    // Active P2P connections will be closed.
    if ([self.twinlife status] != TLTwinlifeStatusStarted || ![self.jobService canReconnect]) {
        return;
    }

    if (![conversation hasPeer]) {
        return;
    }

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    TLConversationConnection *connection;
    @synchronized(self) {
        connection = [conversation startOutgoingWithTimestamp:now twinlife:self.twinlife];
        if (!connection) {
            return;
        }
    }
    
    if (self.lockIdentifier) {
        // Lock the conversation object in the database.
        // If it is locked, don't try to open the connection because another process is using it.
        int64_t lockTime = [self.serviceProvider lockConversation:conversation lockIdentifier:self.lockIdentifier now:now];
        if (lockTime == 0) {
            return;
        }
        conversation.lastConnectTime = lockTime;
    }
    
    TLNotificationContent* notification = [self.scheduler prepareNotificationWithConversation:conversation];
    if (!notification) {
        if (self.lockIdentifier) {
            // No pending operation, release the lock.
            [self.serviceProvider unlockConversation:conversation lockIdentifier:self.lockIdentifier connected:NO];
        }
        return;
    }

    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    
    TLOffer *offer = [[TLOffer alloc] initWithAudio:NO video:NO videoBell:NO data:YES];
    TLOfferToReceive *offerToReceive = [[TLOfferToReceive alloc] initWithAudio:NO video:NO data:YES];
    [self.peerConnectionService createOutgoingPeerConnectionWithSubject:conversation.subject peerTwincodeOutbound:peerTwincodeOutbound offer:offer offerToReceive:offerToReceive notificationContent:notification dataChannelDelegate:self delegate:self withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *peerConnectionId) {
        if (!peerConnectionId) {
            [self closeWithConnection:connection isIncoming:NO peerConnectionId:nil terminateReason:[TLPeerConnectionService toTerminateReason:errorCode]];
            return;
        }

        int64_t requestId = [TLTwinlife newRequestId];
        @synchronized(self) {
            [self.peerConnectionId2Conversation setObject:connection forKey:peerConnectionId];
            [connection startOutgoingConversationWithRequestId:requestId peerConnectionId:peerConnectionId now:now];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, OPENING_TIMEOUT * NSEC_PER_SEC), self.executorQueue, ^{
            [self onOpenTimeoutWithConnection:connection requestId:requestId];
        });
    }];
}

- (void)onOpenTimeoutWithConnection:(nonnull TLConversationConnection *)connection requestId:(int64_t) requestId {
    DDLogVerbose(@"%@ onOpenTimeoutWithConnection: %@ requestId: %lld", LOG_TAG, connection, requestId);
    
    NSUUID *peerConnectionId;
    BOOL isIncoming;
    @synchronized(self) {
        // Ignore the timeout for a previous request.
        if (connection.currentOpeningRequestId != requestId) {
            return;
        }
        if (connection.outgoingState == TLConversationStateOpening) {
            peerConnectionId = connection.outgoingPeerConnectionId;
            isIncoming = NO;
        } else if (connection.incomingState == TLConversationStateOpening) {
            peerConnectionId = connection.incomingPeerConnectionId;
            isIncoming = YES;
        } else {
            peerConnectionId = NULL;
            isIncoming = NO;
        }

        // We are going to terminate this P2P connection and we know its conversation
        // but we don't want closeWithPeerConnectionId to do anything.
        if (peerConnectionId) {
            [self.peerConnectionId2Conversation removeObjectForKey:peerConnectionId];
        }
    }
    
    if (peerConnectionId) {
        [self closeWithConnection:connection isIncoming:isIncoming peerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonTimeout];
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonTimeout];
    }
}

- (void)closeWithPeerConnectionId:peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ closeWithPeerConnectionId: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
    
    TLConversationConnection *connection;
    @synchronized(self) {
        connection = self.peerConnectionId2Conversation[peerConnectionId];
    }
    if (!connection) {
        return;
    }
    DDLogVerbose(@"%@ unlink P2P %@ from conversation %@", LOG_TAG, peerConnectionId, connection);
    if (terminateReason == TLPeerConnectionServiceTerminateReasonGone) {
        DDLogInfo(@"%@ Closing connection %@ terminateReason gone", LOG_TAG, peerConnectionId);
    }

    [self closeWithConnection:connection isIncoming:NO peerConnectionId:peerConnectionId terminateReason:terminateReason];
}

- (void)closeWithConnection:(nonnull TLConversationConnection *)connection isIncoming:(BOOL)isIncoming peerConnectionId:(nullable NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ closeWithConnection: %@ isIncoming: %d peerConnectionId: %@ terminateReason: %d", LOG_TAG, connection, isIncoming, peerConnectionId, terminateReason);

    TLConversationImpl *conversationImpl = connection.conversation;

    // A DISCONNECTED or CONNECTIVITY_ERROR indicates that the current P2P data channel is now broken.
    // we want to retry immediately if the connection was opened.
    BOOL retryImmediately = terminateReason == TLPeerConnectionServiceTerminateReasonDisconnected || terminateReason == TLPeerConnectionServiceTerminateReasonConnectivityError;
    NSMapTable<TLFileDescriptor *, TLReceivingFileInfo *> *receivingFiles;
    NSMapTable<TLFileDescriptor *, TLSendingFileInfo *> *sendingFiles;
    TLConversationState state;
    @synchronized(self) {
        state = [connection state];
        retryImmediately = retryImmediately && state == TLConversationStateOpen;
        if (![connection closeWithPeerConnectionId:peerConnectionId isIncoming:&isIncoming]) {
            DDLogInfo(@"%@ conversation close one direction still opened: %@ terminateReason: %d", LOG_TAG, peerConnectionId, terminateReason);
            return;
        }
        if (peerConnectionId) {
            [self.peerConnectionId2Conversation removeObjectForKey:peerConnectionId];
        }
        receivingFiles = connection.receivingFiles;
        sendingFiles = connection.sendingFiles;
        connection.receivingFiles = nil;
        connection.sendingFiles = nil;
    }
    
    // If there are some open files being received or sent, close them.
    if (sendingFiles) {
        for (TLFileDescriptor *fileDescriptor in sendingFiles) {
            TLSendingFileInfo *sendingFile = [sendingFiles objectForKey:fileDescriptor];
            if (sendingFile) {
                [sendingFile cancel];
            }
        }
    }
    
    if (receivingFiles) {
        for (TLFileDescriptor *fileDescriptor in receivingFiles) {
            TLReceivingFileInfo *receivingFile = [receivingFiles objectForKey:fileDescriptor];
            if (receivingFile) {
                // Now we can update the descriptor in the database.
                [self.serviceProvider updateWithDescriptor:fileDescriptor];
                [receivingFile cancel];
            }
        }
    }

    // This peer has gone or was revoked, there is no need to try again nor to keep the conversation.
    // Inform the upper layer so that the conversation is cleaned.
    if (terminateReason == TLPeerConnectionServiceTerminateReasonRevoked) {
        [self deleteConversation:conversationImpl];
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onRevokedWithConversation:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onRevokedWithConversation:conversationImpl];
                });
            }
        }
        return;
    }
    [conversationImpl nextDelayWithTerminateReason:terminateReason];
    
    if (self.lockIdentifier) {
        // Release the conversation lock in the database.
        int64_t lockTime = [self.serviceProvider unlockConversation:conversationImpl lockIdentifier:self.lockIdentifier connected:state == TLConversationStateOpen];
        if (lockTime) {
            conversationImpl.lastConnectTime = lockTime;
        }
    }
    
    BOOL synchronizePeerNotification = [self.scheduler closeWithConnection:connection];

    // Try to handle and recover from some errors.
    if (terminateReason == TLPeerConnectionServiceTerminateReasonNotEncrypted
        || terminateReason == TLPeerConnectionServiceTerminateReasonDecryptError
        || terminateReason == TLPeerConnectionServiceTerminateReasonNoPublicKey
        || terminateReason == TLPeerConnectionServiceTerminateReasonNoPrivateKey
        || terminateReason == TLPeerConnectionServiceTerminateReasonNoSecretKey) {
        TLTwincodeOutbound *twincodeOutbound = conversationImpl.subject.twincodeOutbound;
        TLTwincodeOutbound *peerTwincodeOutbound = conversationImpl.peerTwincodeOutbound;
        if (twincodeOutbound && [twincodeOutbound isSigned] && peerTwincodeOutbound
            && ![peerTwincodeOutbound.uuid isEqual:twincodeOutbound.uuid]) {

            // The need-secret process can work only if our twincode is signed and the peer knows our public key.
            //
            // Outgoing P2P:
            // - if we failed to create the P2P connection, we must trigger the need-secret because there
            //   is an issue on some public key, private key, or secret key.
            //   In that case, the peer does not receive any terminate reason because the session-initiate is not sent.
            //   => (!isIncoming && peerConnectionId == null)
            // - if our outgoing P2P was refused with NOT_ENCRYPTED, we must also trigger the need-secret
            //   => (!isIncoming && terminateReason == TerminateReason.NOT_ENCRYPTED)
            // - if we get a NO_SECRET_KEY, we either failed to decrypt the peer SDP or the peer failed
            //
            // Incoming P2P:
            // - we almost always trigger the need-secret except for the NOT_ENCRYPTED case which is
            //   handled by the outgoing peer.
            // - if we are missing the keys, send a need-secret invocation.
            // - if we have an EncryptError it means the two peers are now de-synchronized
            //   on their secrets (mostly due to a bug), the need-secret is also triggered but only on one side.
            if ((!isIncoming && (!peerConnectionId || terminateReason == TLPeerConnectionServiceTerminateReasonNotEncrypted))
                || (isIncoming && terminateReason != TLPeerConnectionServiceTerminateReasonNotEncrypted)) {
                NSMutableArray *attributes = [[NSMutableArray alloc] init];
                
                // For a group, add our own member twincode so that the peer can identify us within the group.
                if ([conversationImpl isGroup]) {
                    NSString *memberTwincodeId = conversationImpl.twincodeOutboundId.UUIDString;
                    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:[TLConversationProtocol invokeTwincodeActionMemberTwincodeOutboundId] stringValue:memberTwincodeId]];
                }
                
                [self.twincodeOutboundService invokeTwincodeWithTwincode:peerTwincodeOutbound options:TLInvokeTwincodeWakeup action:[TLConversationProtocol ACTION_CONVERSATION_NEED_SECRET] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                }];
            }
        }
    }

    retryImmediately = retryImmediately && [self.scheduler hasOperationsWithConversation:conversationImpl];
    if (!retryImmediately && synchronizePeerNotification) {
        [self askConversationSynchronizeWithConversation:conversationImpl];
    }
    
    if (retryImmediately) {
        [self executeOperationWithConversation:conversationImpl];
    } else {
        [self.scheduler scheduleOperationsWithConversation:conversationImpl];
    }
}

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLPeerConnectionBinaryPacketListener)listener {
    DDLogVerbose(@"%@ addPacketListener: %@", LOG_TAG, serializer);

    TLSerializerKey *key = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
    self.binaryPacketListeners[key] = [[TLPeerConnectionPacketHandler alloc] initWithSerializer:serializer listener:listener];
    [self.twinlife.serializerFactory addSerializer:serializer];
}

- (nullable TLConversationConnection *)preparePeerConversationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerTwincodeOutboundId:(nullable NSUUID *)peerTwincodeOutboundId peerResourceId:(nullable NSUUID *)peerResourceId {
    DDLogVerbose(@"%@ preparePeerConversationWithPeerConnectionId: %@ peerTwincodeOutboundId: %@ peerResourceId: %@", LOG_TAG, peerConnectionId, peerTwincodeOutboundId, peerResourceId);

    TLConversationConnection *connection;
    @synchronized(self) {
        connection = self.peerConnectionId2Conversation[peerConnectionId];
    }
    if (!connection) {
        DDLogVerbose(@"%@ missing link for P2P %@", LOG_TAG, peerConnectionId);
        return nil;
    }

    TLConversationImpl *conversationImpl = connection.conversation;
    TLGroupConversationImpl *groupConversation = [conversationImpl groupConversation];
    if (groupConversation && conversationImpl == groupConversation.incomingConversation) {
        if (!peerTwincodeOutboundId) {
            return nil;
        }

        conversationImpl = [groupConversation getMemberWithTwincodeId:peerTwincodeOutboundId];
        BOOL newMember = NO;
        if (!conversationImpl) {
            conversationImpl = [self.serviceProvider createGroupMemberWithConversation:groupConversation memberTwincodeId:peerTwincodeOutboundId permissions:0 invitedContactId:nil];
            if (!conversationImpl) {
                return nil;
            }
            newMember = YES;
        }

        // Move the incoming P2P conversation to the group member conversation and
        // setup a new idle timer for the group member conversation.
        TLConversationConnection *oldConnection = connection;
        @synchronized(self) {
            connection = [conversationImpl transferWithConnection:oldConnection twinlife:self.twinlife];
            [self.peerConnectionId2Conversation setObject:connection forKey:peerConnectionId];
        }

        // Tell the scheduler the group incoming conversation can be dropped and it must now track the member conversation.
        // The group incoming conversation has no operation but the member's conversation can have pending operations.
        [self.scheduler closeWithConnection:oldConnection];
        [self.scheduler startOperationsWithConnection:connection state:TLConversationStateOpen];
        if (newMember) {
            DDLogVerbose(@"%@ auto-link P2P %@ to conversation %@", LOG_TAG, peerConnectionId, conversationImpl.uuid);
        } else {
            DDLogVerbose(@"%@ group-link P2P %@ to conversation %@", LOG_TAG, peerConnectionId, conversationImpl.uuid);
        }
        
        if (self.lockIdentifier) {
            int64_t lastConnectDate = [self.serviceProvider lockConversation:conversationImpl lockIdentifier:self.lockIdentifier now:[[NSDate date] timeIntervalSince1970] * 1000];
            if (lastConnectDate) {
                conversationImpl.lastConnectTime = lastConnectDate;
            }
            lastConnectDate = [self.serviceProvider unlockConversation:groupConversation.incomingConversation lockIdentifier:self.lockIdentifier connected:YES];
            if (lastConnectDate) {
                groupConversation.incomingConversation.lastConnectTime = lastConnectDate;
            }
        }
    }

    if (peerResourceId && ![peerResourceId isEqual:NOT_DEFINED_PEER_TWINCODE_OUTBOUND_ID]) {
        BOOL updated = NO;
        BOOL hardReset = NO;
        NSUUID *lResourceId = conversationImpl.peerResourceId;

        if (!lResourceId) {
            updated = YES;
        } else if (![lResourceId isEqual:peerResourceId]) {
            updated = YES;
            hardReset = YES;
        }
#if ENABLE_HARD_RESET
        if (hardReset) {
            NSDictionary<NSUUID *, TLDescriptorId *> *resetList = [self getDescriptorsToDeleteWithConversation:conversationImpl resetDate:LONG_MAX];

            [self resetWithConversation:conversationImpl resetList:resetList clearMode:TLConversationServiceClearBoth];
            
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onResetConversationWithRequestId:conversation:clearMode:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onResetConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation clearMode:TLConversationServiceClearBoth];
                    });
                }
            }

            if (peerTwincodeOutboundId) {
                
                // Create a clear descriptor with the peer's twincode and use a fixed sequence number.
                int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
                TLClearDescriptor *clearDescriptor = (TLClearDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
                    TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.peerTwincodeOutboundId sequenceId:1];

                    TLClearDescriptor *result = [[TLClearDescriptor alloc] initWithDescriptorId:did conversationId:cid clearTimestamp:now];
                    [result setSentTimestamp:now];
                    [result setReceivedTimestamp:now];
                    return result;
                }];

                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onPushDescriptorRequestId:conversation:descriptor:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onPushDescriptorRequestId:TLBaseService.DEFAULT_REQUEST_ID conversation:conversation descriptor:clearDescriptor];
                        });
                    }
                }
            }
        }
#endif
        if (hardReset) {
            [self.twinlife assertionWithAssertPoint:[TLConversationServiceAssertPoint RESET_CONVERSATION], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithSubject:conversationImpl.subject], [TLAssertValue initWithResourceId:lResourceId], [TLAssertValue initWithResourceId:peerResourceId], nil];
        }

        // Update after the hard reset to make sure it was made completely (if it was interrupted, we will do it again).
        if (updated) {
            conversationImpl.peerResourceId = peerResourceId;
            [self.serviceProvider updateConversation:conversationImpl];
        }
    }

    [connection touch];
    return connection;
}

- (int)getDeviceStateWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ getDeviceStateWithConnection: %@", LOG_TAG, connection);

    int result = 0;

    if ([self.scheduler hasOperationsWithConversation:connection.conversation]) {
        result |= DEVICE_STATE_HAS_OPERATIONS;
    }

    if ([self.jobService isForeground]) {
        result |= DEVICE_STATE_FOREGROUND;
    }

    if (connection.synchronizeKeys) {
        result |= DEVICE_STATE_SYNCHRONIZE_KEYS;
    }

    return result;
}

- (void)askConversationSynchronizeWithConversation:(TLConversationImpl*) conversation {
    DDLogVerbose(@"%@ askConversationSynchronizeWithConversation: %@", LOG_TAG, conversation);

    NSMutableArray *attributes = [[NSMutableArray alloc] init];
    
    // For a group, add our own member twincode so that the peer can identify us within the group.
    if ([conversation isGroup]) {
        NSString *memberTwincodeId = conversation.twincodeOutboundId.UUIDString;
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:[TLConversationProtocol invokeTwincodeActionMemberTwincodeOutboundId] stringValue:memberTwincodeId]];
    }

    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    DDLogVerbose(@"%@ invokeTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, peerTwincodeOutbound, attributes);
    conversation.needSynchronize = YES;
    [self.twincodeOutboundService invokeTwincodeWithTwincode:peerTwincodeOutbound options:TLInvokeTwincodeWakeup action:[TLConversationProtocol ACTION_CONVERSATION_SYNCHRONIZE] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
        if (errorCode == TLBaseServiceErrorCodeSuccess && invocationId != nil) {
            TLSynchronizeConversationOperation *synchronizeConversationOperation = [[TLSynchronizeConversationOperation alloc] initWithConversation:conversation];
            conversation.needSynchronize = NO;
            [self.serviceProvider storeOperation:synchronizeConversationOperation];
            [self.scheduler addOperation:synchronizeConversationOperation conversation:conversation delay:0.0];
            
        } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            TLGroupConversationImpl *groupConversation = [conversation groupConversation];
            if (groupConversation) {
                // The group member was removed.
                [self.groupManager delMember:groupConversation memberTwincodeId:peerTwincodeOutbound.uuid];
            } else {
                [self deleteConversation:conversation];
            }
        }
    }];
}
- (void)closeWithConnection:(nonnull TLConversationConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    
    NSUUID *peerConnectionId = connection.peerConnectionId;
    if (peerConnectionId) {
        [self closeWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
        [self.peerConnectionService terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:terminateReason];
    }
}

- (void)deleteConversation:(nonnull TLConversationImpl *)conversationImpl {
    DDLogVerbose(@"%@ deleteConversation: %@", LOG_TAG, conversationImpl);

    TLGroupConversationImpl *groupConversation = [conversationImpl groupConversation];
    if (groupConversation) {
        // This is a group conversation, remove it from the list of known groups.
        [groupConversation delMemberWithTwincodeId:conversationImpl.peerTwincodeOutboundId];
    }
    
    [self.scheduler removeOperationsWithConversation:conversationImpl deletedOperations:nil];
    [self.serviceProvider deleteConversationWithConversation:conversationImpl];
    [self deleteFilesWithConversation:conversationImpl];
    // @todo: we should notify here that a conversation was removed.
}

- (void)notifyDeletedConversationWithList:(nonnull NSArray<TLConversationImpl *> *)list {
    DDLogVerbose(@"%@ notifyDeletedConversationWithList: %@", LOG_TAG, list);

    dispatch_async([self.twinlife twinlifeQueue], ^{
        for (TLConversationImpl *conversation in list) {
            [self.scheduler removeOperationsWithConversation:conversation deletedOperations:nil];

            // If there is a P2P connection for this conversation, close it.
            TLConversationConnection *connection = conversation.connection;
            if (connection) {
                [self closeWithConnection:connection terminateReason:TLPeerConnectionServiceTerminateReasonGone];
            }
        }
    });
}

- (void)resyncGroups {
    DDLogVerbose(@"%@ resyncGroups", LOG_TAG);
#if 0
    // Collect the group members.
    NSMutableArray<TLGroupMemberConversationImpl *> *members = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (NSUUID *groupTwincodeId in self.groups) {
            TLGroupConversationImpl *group = self.groups[groupTwincodeId];
            
            if (group) {
                for (NSUUID *memberId in group.members) {
                    TLGroupMemberConversationImpl *memberConversation = group.members[memberId];
                    if (memberConversation && ![memberConversation isLeaving]) {
                        [members addObject:memberConversation];
                    }
                }
            }
        }
    }
    
    // Send a join request to each member we know.  They will answer with a on-join-group response
    // that contains the list of group member they know.
    if (members.count > 0) {
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLGroupMemberConversationImpl *memberConversation in members) {
            TLGroupConversationImpl *group = memberConversation.group;
            TLGroupOperation *groupOperation = [[TLGroupOperation alloc] initWithConversation:memberConversation type:TLConversationServiceOperationTypeJoinGroup groupTwincodeId:group.groupTwincodeId memberTwincodeId:group.twincodeOutboundId permissions:group.permissions];
            
            [pendingOperations setObject:groupOperation forKey:memberConversation];
        }
        [self addOperationsWithMap:pendingOperations];
    }
#endif
}

#pragma mark - Operations support methods

- (BOOL)preparePushWithDescriptor:(nullable TLDescriptor*)descriptor {
    DDLogVerbose(@"%@ preparePushWithDescriptor: %@", LOG_TAG, descriptor);

    if ([descriptor isExpired] || descriptor.deletedTimestamp > 0) {
        return NO;
    }
    if (descriptor.sentTimestamp <= 0) {
        descriptor.sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        [self.serviceProvider updateDescriptorTimestamps:descriptor];
    }

    return YES;
}

- (TLBaseServiceErrorCode)operationNotSupportedWithConnection:(nonnull TLConversationConnection*)connection descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ operationNotSupportedWithConnection: %@", LOG_TAG, descriptor);

    if (descriptor) {
        descriptor.sentTimestamp = -1;
        descriptor.receivedTimestamp = -1;
        descriptor.readTimestamp = -1;
        [self updateWithDescriptor:descriptor conversation:connection.conversation];
    }
    [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeFeatureNotSupportedByPeer errorParameter:[connection.conversation.uuid UUIDString]];

    return TLBaseServiceErrorCodeFeatureNotSupportedByPeer;
}

- (TLBaseServiceErrorCode)deleteFileDescriptorWithConnection:(nonnull TLConversationConnection*)connection fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor operation:(nonnull TLConversationServiceOperation *)operation {
    
    [self.scheduler removeOperation:operation];

    // File was removed, send a delete descriptor operation.
    TLConversationImpl *conversationImpl = connection.conversation;
    TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeDelete descriptorId:fileDescriptor.descriptorId timestamp:fileDescriptor.deletedTimestamp];
    [self.serviceProvider storeOperation:updateDescriptorTimestampOperation];
    [self.scheduler addOperation:updateDescriptorTimestampOperation conversation:conversationImpl delay:0.0];
    return TLBaseServiceErrorCodeQueued;
}

- (nullable TLSignatureInfoIQ *)createSignatureWithConnection:(nonnull TLConversationConnection *)connection groupTwincodeId:(nonnull NSUUID *)groupTwincodeId {
    DDLogVerbose(@"%@ createSignatureWithConnection: %@ groupTwincodeId: %@", LOG_TAG, connection, groupTwincodeId);

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    TLTwincodeOutbound *memberTwincode = groupConversation ? groupConversation.subject.twincodeOutbound : nil;
    TLTwincodeOutbound *peerTwincode = connection.conversation.peerTwincodeOutbound;
    return memberTwincode && peerTwincode ? [[self.twinlife getCryptoService] getSignatureInfoIQWithTwincode:memberTwincode peerTwincode:peerTwincode renew:NO] : nil;
}

- (nullable TLDescriptor *)loadDescriptorWithId:(int64_t)descriptorId {
    
    return [self.serviceProvider loadDescriptorWithId:descriptorId];
}

- (void)updateDescriptorTimestamps:(nonnull TLDescriptor *)descriptor {
    
    [self.serviceProvider updateDescriptorTimestamps:descriptor];
}

#pragma mark - Operation methods

- (void)executeOperationWithConversation:(TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ executeOperationWithConversation: %@", LOG_TAG, conversation);
    
    dispatch_async(self.executorQueue, ^{
        [self executeOperationInternalWithConversation:conversation];
    });
}

- (void)executeFirstOperationWithConversation:(nonnull TLConversationImpl *)conversation operation:(nonnull TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ executeFirstOperationWithConversation: %@", LOG_TAG, conversation);
    
    dispatch_async(self.executorQueue, ^{
        if ([operation isInvokeTwincode]) {
            TLBaseServiceErrorCode errorCode = [operation executeInvokeWithConversation:conversation conversationService:self];
            if (errorCode != TLBaseServiceErrorCodeQueued) {
                [self.scheduler finishInvokeOperation:operation conversation:conversation];
            }
        } else {
            TLConversationConnection *connection = conversation.connection;
            if (connection && [connection state] == TLConversationStateOpen) {
                [self sendOperationInternalWithConnection:connection operation:operation];
            } else {
                [self executeOperationInternalWithConversation:conversation];
            }
        }
    });
}

- (void)executeNextOperationWithConnection:(nonnull TLConversationConnection *)connection operation:(nonnull TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ executeNextOperationWithConnection: %@", LOG_TAG, connection);
    
    dispatch_async(self.executorQueue, ^{
        [self sendOperationInternalWithConnection:connection operation:operation];
    });
}

- (void)executeOperationInternalWithConversation:(TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ executeOperationInternalWithConversation: %@", LOG_TAG, conversation);
    
    TLConversationServiceOperation *operation = [self.scheduler getFirstOperationWithConversation:conversation];
    
    if (!operation) {
        return;
    }
    
    DDLogInfo(@"%@ executeOperationInternalWithConversation: %@ operation: %@", LOG_TAG, conversation, operation);
    
    TLConversationState state;
    TLConversationConnection *connection;
    @synchronized(self) {
        connection = conversation.connection;
        state = connection ? [connection state] : TLConversationStateClosed;
    }
    switch (state) {
        case TLConversationStateClosed:
            [self connectWithConversation:conversation];
            break;
            
        case TLConversationStateCreating:
        case TLConversationStateOpening:
            break;
            
        case TLConversationStateOpen:
            [self sendOperationInternalWithConnection:connection operation:operation];
            break;
    }
}

#pragma mark - Send methods

- (void)sendOperationInternalWithConnection:(nonnull TLConversationConnection *)connection operation:(TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ sendOperationInternalWithConnection: %@", LOG_TAG, connection);
    
    @try {
        TLBaseServiceErrorCode errorCode;
        if ([operation isInvokeTwincode]) {
            errorCode = [operation executeInvokeWithConversation:connection.conversation conversationService:self];
        } else {
            errorCode = [operation executeWithConnection:connection];
        }
        if (errorCode != TLBaseServiceErrorCodeQueued) {
            [self.scheduler finishOperation:operation connection:connection];
        }

    } @catch (NSException *exception) {
        /* if (descriptor) {
            descriptor.sentTimestamp = -1;
            descriptor.receivedTimestamp = -1;
            descriptor.readTimestamp = -1;
            [self updateWithDescriptor:descriptor conversation:conversation];
        }*/

        [self.scheduler finishOperation:operation connection:connection];
        
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint EXCEPTION] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (TLConversationServiceOperation *)getOperationWithConversation:(TLConversationImpl *)conversation requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ getOperationWithConversation: %@ requestId: %lld", LOG_TAG, conversation, requestId);
    
    return [self.scheduler getOperationWithConversation:conversation requestId:requestId];
}

- (void)deleteConversationDescriptor:(TLDescriptor *)descriptor requestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ deleteConversationDescriptor: %@", LOG_TAG, descriptor);

    [self.serviceProvider deleteDescriptorWithDescriptor:descriptor conversation:conversation];

    // If this is a normal conversation, check if it still has some descriptors to update the isActive flag.
    if ([conversation isKindOfClass:[TLConversationImpl class]]) {
        TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;
        int count = [self.serviceProvider countDescriptorsWithConversation:conversation];
        conversationImpl.isActive = count != 0;
    }

    NSSet *descriptorList = [[NSSet alloc] initWithObjects:descriptor.descriptorId, nil];
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteDescriptorsWithRequestId:conversation:descriptors:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteDescriptorsWithRequestId:requestId conversation:conversation descriptors:descriptorList];
            });
        }
    }
}

-(void)sendErrorIQWithConnection:(nonnull TLConversationConnection *)connection errorIQ:(TLErrorIQ *)errorIQ {
    DDLogVerbose(@"%@ sendErrorIQWithConnection: %@ errorIQ: %@", LOG_TAG, connection, errorIQ);
    
    int majorVersion = [connection getMaxPeerMajorVersion];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
            [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
            if ([errorIQ isKindOfClass:[TLServiceErrorIQ class]]) {
                [[TLServiceErrorIQ SERIALIZER] serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:errorIQ];
            } else {
                [[TLErrorIQ SERIALIZER] serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:errorIQ];
            }
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateObject data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint SERIALIZE_ERROR] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

#pragma mark - Process methods

- (void)processIQWithConnection:(nonnull TLConversationConnection *)connection schemaId:(NSUUID *)schemaId schemaVersion:(int)schemaVersion iq:(TLIQ *)iq {
    DDLogVerbose(@"%@ processIQWithConnection: %@ schemaId: %@ schemaVersion: %d iq: %@", LOG_TAG, connection, schemaId, schemaVersion, iq);
    
    BOOL processed = NO;
    NSException *exception = NULL;
    switch (iq.type) {
        case TLIQTypeGet: {
            [self.twinlife assertionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_IQ], [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
            break;
        }
            
        case TLIQTypeSet: {
            TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)iq;
            
            @try {
                [self.peerConnectionService incrementStatWithPeerConnectionId:connection.peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];
                
                if ([RESET_CONVERSATION_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyResetConversationIQWithConnection:connection resetConversationIQ:(TLConversationServiceResetConversationIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([RESET_CONVERSATION_ACTION_1 isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_1) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_1) {
                            [self processLegacyResetConversationIQWithConnection:connection resetConversationIQ:(TLConversationServiceResetConversationIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_OBJECT_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushObjectIQWithConnection:connection pushObjectIQ:(TLConversationServicePushObjectIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_OBJECT_ACTION_1 isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_1) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_1) {
                            [self processLegacyPushObjectIQWithConnection:connection pushObjectIQ:(TLConversationServicePushObjectIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_TRANSIENT_OBJECT_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushTransientObjectIQWithConnection:connection pushTransientObjectIQ:(TLConversationServicePushTransientObjectIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_FILE_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushFileIQWithConnection:connection pushFileIQ:(TLConversationServicePushFileIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_FILE_CHUNK_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushFileChunkIQWithConnection:connection pushFileChunkIQ:(TLConversationServicePushFileChunkIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_COMMAND_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushCommandIQWithConnection:connection pushCommandIQ:(TLConversationServicePushCommandIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_GEOLOCATION_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushGeolocationIQWithConnection:connection pushGeolocationIQ:(TLConversationServicePushGeolocationIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([PUSH_TWINCODE_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyPushTwincodeIQWithConnection:connection pushTwincodeIQ:(TLConversationServicePushTwincodeIQ *)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([UPDATE_DESCRIPTOR_TIMESTAMP_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyUpdateDescriptorTimestampIQWithConnection:connection updateDescriptorTimestampIQ:(TLUpdateDescriptorTimestampIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([INVITE_GROUP_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyInviteGroupIQWithConnection:connection inviteGroupIQ:(TLConversationServiceInviteGroupIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([REVOKE_INVITE_GROUP_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyRevokeInviteGroupIQWithConnection:connection revokeInviteGroupIQ:(TLConversationServiceRevokeInviteGroupIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([JOIN_GROUP_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyJoinGroupIQWithConnection:connection joinGroupIQ:(TLConversationServiceJoinGroupIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([LEAVE_GROUP_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyLeaveGroupIQWithConnection:connection leaveGroupIQ:(TLConversationServiceLeaveGroupIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([UPDATE_GROUP_MEMBER_ACTION isEqualToString:serviceRequestIQ.action]) {
                    if (serviceRequestIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceRequestIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyUpdateGroupMemberIQWithConnection:connection updateGroupMemberIQ:(TLConversationServiceUpdateGroupMemberIQ*)serviceRequestIQ];
                            processed = YES;
                        }
                    }
                }
            } @catch (NSException *lException) {
                [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_IQ] exception:lException, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithSchemaId:schemaId], [TLAssertValue initWithSchemaVersion:schemaVersion], [TLAssertValue initWithLine:__LINE__], nil];
            }
            if (!processed) {
                TLServiceErrorIQ *serviceErrorIQ = [[TLServiceErrorIQ alloc] initWithId:serviceRequestIQ.id from:connection.from to:connection.to errorType:TLErrorIQTypeCancel condition:TL_ERROR_IQ_BAD_REQUEST requestSchemaId:schemaId requestSchemaVersion:schemaVersion requestId:serviceRequestIQ.requestId service:serviceRequestIQ.service action:serviceRequestIQ.action majorVersion:serviceRequestIQ.majorVersion minorVersion:serviceRequestIQ.minorVersion];
                [self sendErrorIQWithConnection:connection errorIQ:serviceErrorIQ];
            }
            break;
        }
            
        case TLIQTypeResult: {
            TLServiceResultIQ *serviceReplyIQ = (TLServiceResultIQ *)iq;
            
            @try {
                [self.peerConnectionService incrementStatWithPeerConnectionId:connection.peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveResultCount];
                
                if ([ON_RESET_CONVERSATION_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnResetConversationIQWithConnection:connection onResetConversationIQ:(TLConversationServiceOnResetConversationIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_RESET_CONVERSATION_ACTION_1 isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_1) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_1) {
                            [self processLegacyOnResetConversationIQWithConnection:connection onResetConversationIQ:(TLConversationServiceOnResetConversationIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_OBJECT_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushObjectIQWithConnection:connection onPushObjectIQ:(TLConversationServiceOnPushObjectIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_OBJECT_ACTION_1 isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_1) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_1) {
                            [self processLegacyOnPushObjectIQWithConnection:connection onPushObjectIQ:(TLConversationServiceOnPushObjectIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_FILE_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushFileIQWithConnection:connection onPushFileIQ:(TLConversationServiceOnPushFileIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_FILE_CHUNK_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushFileChunkIQWithConnection:connection onPushFileChunkIQ:(TLConversationServiceOnPushFileChunkIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_COMMAND_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushCommandIQWithConnection:connection onPushCommandIQ:(TLConversationServiceOnPushCommandIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_GEOLOCATION_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushGeolocationIQWithConnection:connection onPushGeolocationIQ:(TLConversationServiceOnPushGeolocationIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_PUSH_TWINCODE_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnPushTwincodeIQWithConnection:connection onPushTwincodeIQ:(TLConversationServiceOnPushTwincodeIQ *)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_UPDATE_DESCRIPTOR_TIMESTAMP_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnUpdateDescriptorTimestampIQWithConnection:connection onUpdateDescriptorTimestampIQ:(TLOnUpdateDescriptorTimestampIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_INVITE_GROUP_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnInviteGroupIQWithConnection:connection onInviteGroupIQ:(TLConversationServiceOnResultGroupIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_REVOKE_INVITE_GROUP_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnRevokeInviteGroupIQWithConnection:connection onRevokeInviteGroupIQ:(TLConversationServiceOnResultGroupIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_JOIN_GROUP_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnJoinGroupIQWithConnection:connection onJoinGroupIQ:(TLConversationServiceOnResultJoinGroupIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_LEAVE_GROUP_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnLeaveGroupIQWithConnection:connection onLeaveGroupIQ:(TLConversationServiceOnResultGroupIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                    
                } else if ([ON_UPDATE_GROUP_MEMBER_ACTION isEqualToString:serviceReplyIQ.action]) {
                    if (serviceReplyIQ.majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
                        if (serviceReplyIQ.minorVersion <= MAX_MINOR_VERSION_2) {
                            [self processLegacyOnUpdateGroupMemberIQWithConnection:connection onUpdateGroupMemberIQ:(TLConversationServiceOnResultGroupIQ*)serviceReplyIQ];
                            processed = YES;
                        }
                    }
                }
            } @catch (NSException *lException) {
                exception = lException;
            }
            // If an exception is raised or if we have not handled the response packet, report an assertion but
            // there is no point it returning an error because it will be ignored.
            if (!processed) {
                [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithSchemaId:schemaId], [TLAssertValue initWithSchemaVersion:schemaVersion], [TLAssertValue initWithLine:__LINE__], nil];
            }
            break;
        }
            
        case TLIQTypeError:
            [self.peerConnectionService incrementStatWithPeerConnectionId:connection.peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveErrorCount];
            
            if ([iq isKindOfClass:[TLServiceErrorIQ class]]) {
                [self processOnServiceErrorIQWithConnection:connection onServiceErrorIQ:(TLServiceErrorIQ*)iq];

            } else if ([iq isKindOfClass:[TLErrorIQ class]]) {
                [self processOnErrorIQWithConnection:connection onErrorIQ:(TLErrorIQ*)iq];

            }
            break;
            
        default:
            // TBD
            break;
    }
}

- (void)processResetConversationIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLResetConversationIQ *)iq {
    DDLogVerbose(@"%@ processResetConversationIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLClearDescriptor *clearDescriptor = iq.clearDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    int64_t clearTimestamp = iq.clearTimestamp + [connection peerTimeCorrection];
    int64_t receivedTimestamp;

    if (clearDescriptor == nil || (iq.clearMode != TLConversationServiceClearBoth || ![conversationImpl hasPermissionWithPermission:TLPermissionTypeSendMessage])) {
        receivedTimestamp = -1;
        
        if (![conversationImpl isGroup]) {
            // Mark every descriptor as deleted by the peer.  We get a list of descriptors that are now deleted
            // if they are both deleted locally and by the peer.

            NSSet<TLDescriptorId *> *resetList = [self.serviceProvider markDescriptorDeletedWithConversation:conversationImpl clearDate:clearTimestamp resetDate:clearTimestamp twincodeOutboundId:conversationImpl.twincodeOutboundId keepMediaMessages:iq.clearMode == TLConversationServiceClearMedia];
            if (resetList) {
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onDeleteDescriptorsWithRequestId:conversation:descriptors:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onDeleteDescriptorsWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptors:resetList];
                        });
                    }
                }

            }
        }

    } else {
        // This is a reset conversation on both sides and the user has the permission.
        NSDictionary<NSUUID *, TLDescriptorId *> *resetList = [self getDescriptorsToDeleteWithConversation:conversationImpl.mainConversation resetDate:clearTimestamp];

        BOOL wasActive = conversationImpl.mainConversation.isActive;
        [self resetWithConversation:conversationImpl.mainConversation resetList:resetList clearMode:TLConversationServiceClearBoth];

        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onResetConversationWithRequestId:conversation:clearMode:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onResetConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl.mainConversation clearMode:TLConversationServiceClearBoth];
                });
            }
        }

        if (wasActive) {
            [self popWithDescriptor:clearDescriptor connection:connection];
            receivedTimestamp = clearDescriptor.receivedTimestamp;
        } else {
            receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        }
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnResetConversationIQ SERIALIZER_3] requestId:iq.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultResetConversation iq:onPushIQ];
}

- (void)processLegacyResetConversationIQWithConnection:(nonnull TLConversationConnection *)connection resetConversationIQ:
(TLConversationServiceResetConversationIQ *)resetConversationIQ {
    DDLogVerbose(@"%@ processLegacyResetConversationIQWithConnection: %@ resetConversationIQ: %@", LOG_TAG, connection, resetConversationIQ);
    
    // Verify that the user can reset the conversation.
    TLConversationImpl *conversation = connection.conversation;
    if ([conversation hasPermissionWithPermission:TLPermissionTypeResetConversation]) {
        NSMutableDictionary<NSUUID *, TLDescriptorId *> *resetList = [[NSMutableDictionary alloc] init];
        if ([conversation isKindOfClass:[TLGroupMemberConversationImpl class]]) {
            // Notes:
            // - Messages that have been sent are associated with the GroupConversationImpl object.
            // - Messages that we have received are associated with a GroupMemberConversationImpl object.
            // - The ResetGroupMember holds the max sequence Id for a member as seen by the sender.
            // - For a group, the call to resetConversation() clears only one direction.
            for (TLDescriptorId *member in resetConversationIQ.resetMembers) {
                resetList[member.twincodeOutboundId] = member;
            }
        } else {
            resetList[conversation.twincodeOutboundId] = [[TLDescriptorId alloc] initWithTwincodeOutboundId:conversation.twincodeOutboundId sequenceId:resetConversationIQ.peerMinSequenceId];
            resetList[conversation.peerTwincodeOutboundId] = [[TLDescriptorId alloc] initWithTwincodeOutboundId:conversation.peerTwincodeOutboundId sequenceId:resetConversationIQ.minSequenceId];
        }
        
        if ([self resetWithConversation:conversation resetList:resetList clearMode:TLConversationServiceClearBoth]) {

            // Create a clear descriptor with the peer's twincode and use a fixed sequence number.
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;

            TLClearDescriptor *clearDescriptor = (TLClearDescriptor *)[self.serviceProvider createDescriptorWithConversation:conversation createBlock:^(int64_t descriptorId, int64_t cid, int64_t sequenceId) {
                TLDescriptorId *did = [[TLDescriptorId alloc] initWithId:descriptorId twincodeOutboundId:conversation.peerTwincodeOutboundId sequenceId:1];

                // Create one object descriptor for the conversation.
                TLClearDescriptor *result = [[TLClearDescriptor alloc] initWithDescriptorId:did conversationId:cid clearTimestamp:now];
                [result setSentTimestamp:now];
                [result setReceivedTimestamp:now];
                return result;
            }];

            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onResetConversationWithRequestId:conversation:clearMode:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onResetConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation clearMode:TLConversationServiceClearBoth];
                    });
                }
            }

            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onPopDescriptorWithRequestId:TLBaseService.DEFAULT_REQUEST_ID conversation:conversation descriptor:clearDescriptor];
                    });
                }
            }
        }
    }
    
    int majorVersion = resetConversationIQ.majorVersion;
    int minorVersion = resetConversationIQ.minorVersion;
    
    TLConversationServiceOnResetConversationIQ *onResetConversationIQ = [[TLConversationServiceOnResetConversationIQ alloc] initWithId:resetConversationIQ.id from:connection.from to:connection.to requestId:resetConversationIQ.requestId majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            [TLConversationServiceOnResetConversationIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onResetConversationIQ];
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultResetConversation data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];

    }
}

- (void)processLegacyPushCommandIQWithConnection:(nonnull TLConversationConnection *)connection pushCommandIQ:(TLConversationServicePushCommandIQ *)pushCommandIQ {
    DDLogVerbose(@"%@ processLegacyPushCommandIQWithConnection: %@ pushCommandObjectIQ: %@", LOG_TAG, connection, pushCommandIQ);
    
    TLTransientObjectDescriptor *commandDescriptor = pushCommandIQ.commandDescriptor;
    commandDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:commandDescriptor];
            });
        }
    }
    
    int majorVersion = pushCommandIQ.majorVersion;
    int minorVersion = pushCommandIQ.minorVersion;
    
    TLConversationServiceOnPushCommandIQ *onPushCommandIQ = [[TLConversationServiceOnPushCommandIQ alloc] initWithId:pushCommandIQ.id from:connection.from to:connection.to requestId:pushCommandIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:commandDescriptor.receivedTimestamp];
    
    NSMutableData *data = [onPushCommandIQ serializeWithSerializerFactory:self.twinlife.serializerFactory];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushTransient data:data];
}

- (void)processPushObjectIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushObjectIQ *)iq {
    DDLogVerbose(@"%@ processPushObjectIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLObjectDescriptor *objectDescriptor = iq.objectDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    
    // Verify that the user can send us messages.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendMessage]) {
        [self popWithDescriptor:objectDescriptor connection:connection];
    } else {
        // Send him back a receive failure.
        objectDescriptor.receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushObjectIQ SERIALIZER_3] requestId:iq.requestId deviceState:deviceState receivedTimestamp:objectDescriptor.receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushObject iq:onPushIQ];
}

- (void)processLegacyPushObjectIQWithConnection:(nonnull TLConversationConnection *)connection pushObjectIQ:(TLConversationServicePushObjectIQ *)pushObjectIQ {
    DDLogVerbose(@"%@ processLegacyPushObjectIQWithConnection: %@ pushObjectIQ: %@", LOG_TAG, connection, pushObjectIQ);
    
    TLObjectDescriptor *objectDescriptor = pushObjectIQ.objectDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;

    // Verify that the user can send us messages.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendMessage]) {
        // Invalidate the read timestamp because we could receive a value.
        objectDescriptor.readTimestamp = 0;
        [self popWithDescriptor:objectDescriptor connection:connection];
    } else {
        // Send him back a receive failure.
        objectDescriptor.receivedTimestamp = -1;
    }
    
    int majorVersion = pushObjectIQ.majorVersion;
    int minorVersion = pushObjectIQ.minorVersion;
    
    TLConversationServiceOnPushObjectIQ *onPushObjectIQ = [[TLConversationServiceOnPushObjectIQ alloc] initWithId:pushObjectIQ.id from:connection.from to:connection.to requestId:pushObjectIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:objectDescriptor.receivedTimestamp];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            [TLConversationServiceOnPushObjectIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onPushObjectIQ];
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushObject data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (void)processUpdateObjectIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLUpdateDescriptorIQ *)iq {
    DDLogVerbose(@"%@ processUpdateObjectIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLConversationImpl *conversationImpl = connection.conversation;
    int64_t receivedTimestamp;
    
    // Verify that the user can send us messages.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendMessage]) {
        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:iq.descriptorId];
        if (descriptor) {
            receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;

            BOOL updated = NO;
            TLConversationServiceUpdateType updateType = TLConversationServiceUpdateTypeTimestamps;
            if ([descriptor isKindOfClass:[TLObjectDescriptor class]]) {
                TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)descriptor;

                updated = [objectDescriptor updateWithMessage:iq.message];
                if (updated) {
                    [objectDescriptor markEdited];
                }
                updateType = updated ? TLConversationServiceUpdateTypeContent : TLConversationServiceUpdateTypeProtection;
                updated |= [objectDescriptor updateWithCopyAllowed:iq.flagCopyAllowed];
                updated |= [objectDescriptor updateWithExpireTimeout:iq.expiredTimeout];

            } else if ([descriptor isKindOfClass:[TLFileDescriptor class]]) {
                TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)descriptor;
                
                updated = [fileDescriptor updateWithCopyAllowed:iq.flagCopyAllowed];
                updated |= [fileDescriptor updateWithExpireTimeout:iq.expiredTimeout];
                updateType = TLConversationServiceUpdateTypeProtection;

            } else {
                updated = NO;
            }
            if (updated) {
                descriptor.updatedTimestamp = [connection adjustedTimeWithTimestamp:iq.updatedTimestamp];
                [self.serviceProvider updateWithDescriptor:descriptor];

                // If the message was inserted, propagate it to upper layers through the onPopDescriptor callback.
                // Otherwise, we already know the message and we only need to acknowledge the sender.
                connection.conversation.isActive = YES;
                    
                id<TLConversation> conversation = connection.conversation.mainConversation;
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor updateType:updateType];
                        });
                    }
                    if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor];
                        });
                    }
                }
            }
        } else {
            receivedTimestamp = -1L;
        }
    } else {
        // Send him back a receive failure.
        receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdateDescriptorIQ SERIALIZER_1] requestId:iq.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushObject iq:onPushIQ];
}

- (void)processPushTransientIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushTransientIQ *)pushTransientObjectIQ {
    DDLogVerbose(@"%@ processPushTransientIQWithConnection: %@ pushTransientObjectIQ: %@", LOG_TAG, connection, pushTransientObjectIQ);
    
    TLTransientObjectDescriptor *transientObjectDescriptor = pushTransientObjectIQ.descriptor;
    transientObjectDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:transientObjectDescriptor];
            });
        }
    }
    
    if (pushTransientObjectIQ.flags) {
        int deviceState = [self getDeviceStateWithConnection:connection];
        TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushCommandIQ SERIALIZER_2] requestId:pushTransientObjectIQ.requestId deviceState:deviceState receivedTimestamp:transientObjectDescriptor.receivedTimestamp];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushTransient iq:onPushIQ];
    }
}

- (void)processLegacyPushTransientObjectIQWithConnection:(nonnull TLConversationConnection *)connection pushTransientObjectIQ:(TLConversationServicePushTransientObjectIQ *)pushTransientObjectIQ {
    DDLogVerbose(@"%@ processLegacyPushTransientObjectIQWithConnection: %@ pushTransientObjectIQ: %@", LOG_TAG, connection, pushTransientObjectIQ);
    
    TLTransientObjectDescriptor *transientObjectDescriptor = pushTransientObjectIQ.transientObjectDescriptor;
    transientObjectDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:transientObjectDescriptor];
            });
        }
    }
}

- (void)processPushThumbnailIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushFileChunkIQ *)iq {
    DDLogVerbose(@"%@ processPushThumbnailIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    if (!iq.chunk) {
        return;
    }

    // Verify that the user can send us file/audio/image/video.
    TLConversationImpl *conversationImpl = connection.conversation;
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendVideo]
        || [conversationImpl hasPermissionWithPermission:TLPermissionTypeSendAudio]
        || [conversationImpl hasPermissionWithPermission:TLPermissionTypeSendImage]
        || [conversationImpl hasPermissionWithPermission:TLPermissionTypeSendFile]) {
        
        // Create the path and save the optional thumbnail only when the permission is granted.
        [self writeThumbnailWithDescriptorId:iq.descriptorId thumbnailData:iq.chunk append:iq.chunkStart > 0];
    }
}

- (void)processPushFileIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushFileIQ *)iq {
    DDLogVerbose(@"%@ processPushFileIQWithConnection: %@ pushFileIQ: %@", LOG_TAG, connection, iq);

    TLFileDescriptor *fileDescriptor = iq.fileDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    TLPermissionType permission;
    
    switch ([fileDescriptor getType]) {
        case TLDescriptorTypeVideoDescriptor:
            permission = TLPermissionTypeSendVideo;
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            permission = TLPermissionTypeSendAudio;
            break;
            
        case TLDescriptorTypeImageDescriptor:
            permission = TLPermissionTypeSendImage;
            break;
            
        case TLDescriptorTypeNamedFileDescriptor:
            permission = TLPermissionTypeSendFile;
            break;
            
        default:
            permission = TLPermissionTypeNone;
            break;
    }
    // Verify that the user can send us file/audio/image/video.
    if ([conversationImpl hasPermissionWithPermission:permission]) {
        
        // Create the path and save the optional thumbnail only when the permission is granted.
        NSString *path = [self saveThumbnailWithDescriptor:fileDescriptor thumbnailData:iq.thumbnail];
        if (!path) {
            // Don't create the file descriptor if we cannot save the file, report a failure to the caller.
            fileDescriptor.receivedTimestamp = -1;
        } else {
            // fileDescriptor.path = path;
            [self popWithDescriptor:fileDescriptor connection:connection];
        }
    } else {
        // Send him back a receive failure.
        fileDescriptor.receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushFileIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:fileDescriptor.receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushFile iq:onPushIQ];
}

- (void)processLegacyPushFileIQWithConnection:(nonnull TLConversationConnection *)connection pushFileIQ:(TLConversationServicePushFileIQ *)pushFileIQ {
    DDLogVerbose(@"%@ processLegacyPushFileIQWithConnection: %@ pushFileIQ: %@", LOG_TAG, connection, pushFileIQ);
    
    TLFileDescriptor *fileDescriptor = pushFileIQ.fileDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    TLPermissionType permission;
    
    switch ([fileDescriptor getType]) {
        case TLDescriptorTypeVideoDescriptor:
            permission = TLPermissionTypeSendVideo;
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            permission = TLPermissionTypeSendAudio;
            break;
            
        case TLDescriptorTypeImageDescriptor:
            permission = TLPermissionTypeSendImage;
            break;
            
        case TLDescriptorTypeNamedFileDescriptor:
            permission = TLPermissionTypeSendFile;
            break;
            
        default:
            permission = TLPermissionTypeNone;
            break;
    }
    // Verify that the user can send us file/audio/image/video.
    if ([conversationImpl hasPermissionWithPermission:permission]) {
        
        // Create the path only when the permission is granted.
        NSString *path = [self getPathWithDescriptor:fileDescriptor extension:fileDescriptor.extension];
        if (!path) {
            // Don't create the file descriptor if we cannot save the file, report a failure to the caller.
            fileDescriptor.receivedTimestamp = -1;
        } else {
            // fileDescriptor.path = path;
            // Invalidate the read timestamp because we could receive a value.
            fileDescriptor.readTimestamp = 0;
            [self popWithDescriptor:fileDescriptor connection:connection];
        }
    } else {
        // Send him back a receive failure.
        fileDescriptor.receivedTimestamp = -1;
    }
    
    int majorVersion = pushFileIQ.majorVersion;
    int minorVersion = pushFileIQ.minorVersion;
    
    TLConversationServiceOnPushFileIQ *onPushFileIQ = [[TLConversationServiceOnPushFileIQ alloc] initWithId:pushFileIQ.id from:connection.from to:connection.to requestId:pushFileIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:fileDescriptor.receivedTimestamp];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            [TLConversationServiceOnPushFileIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onPushFileIQ];
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushFile data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (void)processPushFileChunkIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushFileChunkIQ *)iq {
    DDLogVerbose(@"%@ processPushFileChunkIQWithConnection: %@ id: %@", LOG_TAG, connection, iq);

    TLFileDescriptor *fileDescriptor;
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:iq.descriptorId];
    TLOnPushFileChunkIQ *onPushFileChunkIQ;
    int deviceState = [self getDeviceStateWithConnection:connection];
    BOOL isAvailable;
    if (!descriptor || ![descriptor isKindOfClass:[TLFileDescriptor class]]) {
        // The descriptor may not exist if there was a creation failure in processPushFileIQ().
        // If we don't respond, the other peer will hang until we reply.  By returning a -1 receive time and
        // a LONG value, the peer will mark the file as not being received and will also stop sending us more chunks.
        onPushFileChunkIQ = [[TLOnPushFileChunkIQ alloc] initWithSerializer:[TLOnPushFileChunkIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:-1 senderTimestamp:iq.timestamp nextChunkStart:LONG_MAX];
        fileDescriptor = nil;
        isAvailable = NO;
    } else {
        fileDescriptor = (TLFileDescriptor *)descriptor;
        
        int64_t now;
        int64_t end = [connection writeChunkWithFileDescriptor:fileDescriptor chunkStart:iq.chunkStart chunk:iq.chunk];
        if (end >= 0) {
            now = [[NSDate date] timeIntervalSince1970] * 1000;
            fileDescriptor.end = end;
            fileDescriptor.updatedTimestamp = now;
            fileDescriptor.receivedTimestamp = now;
            isAvailable = [fileDescriptor isAvailable];
            if (isAvailable) {
                [self.serviceProvider updateWithDescriptor:fileDescriptor];
            }
        } else {
            // Something wrong happened when saving the file, report and error to the peer.
            // (SD card could be full).
            // Don't return a negative value: we want the peer to stop sending more chunks.
            // The file being incomplete, there is no way to access and view it so we remove
            // the file descriptor and the file itself.
            [self deleteConversationDescriptor:fileDescriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation];
            now = -1;
            fileDescriptor.updatedTimestamp = now;
            fileDescriptor.receivedTimestamp = now;
            end = LONG_MAX;
            isAvailable = NO;
        }
        
        onPushFileChunkIQ = [[TLOnPushFileChunkIQ alloc] initWithSerializer:[TLOnPushFileChunkIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:now senderTimestamp:iq.timestamp nextChunkStart:end];
    }
    
    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushFileChunk iq:onPushFileChunkIQ];

    // Notify the progress only when we are in foreground or if we have received the complete file.
    if (fileDescriptor && (isAvailable || (deviceState & DEVICE_STATE_FOREGROUND) != 0)) {
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:fileDescriptor updateType:TLConversationServiceUpdateTypeContent];
                });
            }
        }
    }
}

- (void)processLegacyPushFileChunkIQWithConnection:(nonnull TLConversationConnection *)connection pushFileChunkIQ:(TLConversationServicePushFileChunkIQ *)pushFileChunkIQ {
    DDLogVerbose(@"%@ processLegacyPushFileChunkIQWithConnection: %@ pushFileChunkIQ: %@", LOG_TAG, connection, pushFileChunkIQ);
    
    int majorVersion = pushFileChunkIQ.majorVersion;
    int minorVersion = pushFileChunkIQ.minorVersion;
    
    // TBD chunkStart...
    TLFileDescriptor *fileDescriptor;
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:pushFileChunkIQ.descriptorId];
    TLConversationServiceOnPushFileChunkIQ *onPushFileChunkIQ;
    BOOL isAvailable;
    if (!descriptor || ![descriptor isKindOfClass:[TLFileDescriptor class]]) {
        // The descriptor may not exist if there was a creation failure in processPushFileIQ().
        // If we don't respond, the other peer will hang until we reply.  By returning a -1 receive time and
        // a LONG value, the peer will mark the file as not being received and will also stop sending us more chunks.
        onPushFileChunkIQ = [[TLConversationServiceOnPushFileChunkIQ alloc] initWithId:pushFileChunkIQ.id from:connection.from to:connection.to requestId:pushFileChunkIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:-1 nextChunkStart:LONG_MAX];
        fileDescriptor = nil;
        isAvailable = NO;
    } else {
        fileDescriptor = (TLFileDescriptor *)descriptor;
        
        int64_t now;
        int64_t end = [connection writeChunkWithFileDescriptor:fileDescriptor chunkStart:pushFileChunkIQ.chunkStart chunk:pushFileChunkIQ.chunk];
        if (end >= 0 && pushFileChunkIQ.chunk.length <= end) {
            now = [[NSDate date] timeIntervalSince1970] * 1000;
            fileDescriptor.end = end;
            fileDescriptor.updatedTimestamp = now;
            fileDescriptor.receivedTimestamp = now;
            isAvailable = [fileDescriptor isAvailable];
            if (isAvailable) {
                [self.serviceProvider updateWithDescriptor:fileDescriptor];
            }
        } else {
            // Something wrong happened when saving the file, report and error to the peer.
            // (SD card could be full).
            // Don't return a negative value: we want the peer to stop sending more chunks.
            // The file being incomplete, there is no way to access and view it so we remove
            // the file descriptor and the file itself.
            [self deleteConversationDescriptor:fileDescriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation];
            now = -1;
            fileDescriptor.updatedTimestamp = now;
            fileDescriptor.receivedTimestamp = now;
            end = LONG_MAX;
            isAvailable = NO;
        }
        
        onPushFileChunkIQ = [[TLConversationServiceOnPushFileChunkIQ alloc] initWithId:pushFileChunkIQ.id from:connection.from to:connection.to requestId:pushFileChunkIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:now nextChunkStart:end];
    }
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            [TLConversationServiceOnPushFileChunkIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onPushFileChunkIQ];
            
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushFileChunk data:data];

        // Notify the progress only when we are in foreground or if we have received the complete file.
        if (fileDescriptor && (isAvailable || [self.jobService isForeground])) {
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:fileDescriptor updateType:TLConversationServiceUpdateTypeContent];
                    });
                }
            }
        }
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (void)processPushGeolocationIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushGeolocationIQ *)iq {
    DDLogVerbose(@"%@ processPushGeolocationIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLGeolocationDescriptor *geolocationDescriptor = iq.geolocationDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    
    // Verify that the user can send us geolocation.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendGeolocation]) {
        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:geolocationDescriptor.descriptorId];
        if (descriptor == nil) {
            [self popWithDescriptor:geolocationDescriptor connection:connection];

        } else if ([descriptor isKindOfClass:[TLGeolocationDescriptor class]]) {
            TLGeolocationDescriptor *currentGeolocationDescriptor = (TLGeolocationDescriptor *) descriptor;
            
            // We already know the geolocation and it was updated, propagate through onUpdateDescriptor.
            if ([currentGeolocationDescriptor updateWithDescriptor:geolocationDescriptor]) {
                currentGeolocationDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
                [self.serviceProvider updateWithDescriptor:currentGeolocationDescriptor];
                
                geolocationDescriptor.receivedTimestamp = currentGeolocationDescriptor.receivedTimestamp;
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:currentGeolocationDescriptor updateType:TLConversationServiceUpdateTypeContent];
                        });
                    }
                }
            }
        }
    } else {
        // Send him back a receive failure.
        geolocationDescriptor.receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushGeolocationIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:geolocationDescriptor.receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushGeolocation iq:onPushIQ];
}

- (void)processLegacyPushGeolocationIQWithConnection:(nonnull TLConversationConnection *)connection pushGeolocationIQ:(TLConversationServicePushGeolocationIQ *)pushGeolocationIQ {
    DDLogVerbose(@"%@ processLegacyPushGeolocationIQWithConnection: %@ pushGeolocationIQ: %@", LOG_TAG, connection, pushGeolocationIQ);
    
    TLGeolocationDescriptor *geolocationDescriptor = pushGeolocationIQ.geolocationDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    
    // Verify that the user can send us geolocation.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendGeolocation]) {
        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:geolocationDescriptor.descriptorId];
        if (descriptor == nil) {
            geolocationDescriptor.localMapPath = nil;
            geolocationDescriptor.isValidLocalMap = NO;
            // Invalidate the read timestamp because we could receive a value.
            geolocationDescriptor.readTimestamp = 0;
            [self popWithDescriptor:geolocationDescriptor connection:connection];

        } else if ([descriptor isKindOfClass:[TLGeolocationDescriptor class]]) {
            TLGeolocationDescriptor *currentGeolocationDescriptor = (TLGeolocationDescriptor *) descriptor;
            
            // We already know the geolocation and it was updated, propagate through onUpdateDescriptor.
            if ([currentGeolocationDescriptor updateWithDescriptor:geolocationDescriptor]) {
                currentGeolocationDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
                [self.serviceProvider updateWithDescriptor:currentGeolocationDescriptor];
                
                geolocationDescriptor.receivedTimestamp = currentGeolocationDescriptor.receivedTimestamp;
                for (id delegate in self.delegates) {
                    if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                        id<TLConversationServiceDelegate> lDelegate = delegate;
                        dispatch_async([self.twinlife twinlifeQueue], ^{
                            [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:currentGeolocationDescriptor updateType:TLConversationServiceUpdateTypeContent];
                        });
                    }
                }
            }
        }
    } else {
        // Send him back a receive failure.
        geolocationDescriptor.receivedTimestamp = -1;
    }
    
    int majorVersion = pushGeolocationIQ.majorVersion;
    int minorVersion = pushGeolocationIQ.minorVersion;
    
    TLConversationServiceOnPushGeolocationIQ *onPushGeolocationIQ = [[TLConversationServiceOnPushGeolocationIQ alloc] initWithId:pushGeolocationIQ.id from:connection.from to:connection.to requestId:pushGeolocationIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:geolocationDescriptor.receivedTimestamp];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        
        [TLConversationServiceOnPushGeolocationIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onPushGeolocationIQ];
        serialized = YES;
        
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushGeolocation data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (void)processPushTwincodeIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLPushTwincodeIQ *)iq {
    DDLogVerbose(@"%@ processPushTwincodeIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLTwincodeDescriptor *twincodeDescriptor = iq.twincodeDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    
    // Verify that the user can send us twincodes and that we recognize the schema.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendTwincode] && [self.acceptedPushTwincode containsObject:twincodeDescriptor.schemaId]) {
        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:twincodeDescriptor.descriptorId];
        if (descriptor == nil) {
            [self popWithDescriptor:twincodeDescriptor connection:connection];
        }
    } else {
        // Send him back a receive failure.
        twincodeDescriptor.receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnPushTwincodeIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:twincodeDescriptor.receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultPushTwincode iq:onPushIQ];
}

- (void)processLegacyPushTwincodeIQWithConnection:(nonnull TLConversationConnection *)connection pushTwincodeIQ:(TLConversationServicePushTwincodeIQ *)pushTwincodeIQ {
    DDLogVerbose(@"%@ processLegacyPushTwincodeIQWithConnection: %@ pushTwincodeIQ: %@", LOG_TAG, connection, pushTwincodeIQ);
    
    TLTwincodeDescriptor *twincodeDescriptor = pushTwincodeIQ.twincodeDescriptor;
    TLConversationImpl *conversationImpl = connection.conversation;
    
    // Verify that the user can send us twincodes and that we recognize the schema.
    if ([conversationImpl hasPermissionWithPermission:TLPermissionTypeSendTwincode] && [self.acceptedPushTwincode containsObject:twincodeDescriptor.schemaId]) {
        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:twincodeDescriptor.descriptorId];
        if (descriptor == nil) {
            twincodeDescriptor.readTimestamp = 0;
            [self popWithDescriptor:twincodeDescriptor connection:connection];
        }
    } else {
        // Send him back a receive failure.
        twincodeDescriptor.receivedTimestamp = -1;
    }
    
    int majorVersion = pushTwincodeIQ.majorVersion;
    int minorVersion = pushTwincodeIQ.minorVersion;
    
    TLConversationServiceOnPushTwincodeIQ *onPushTwincodeIQ = [[TLConversationServiceOnPushTwincodeIQ alloc] initWithId:pushTwincodeIQ.id from:connection.from to:connection.to requestId:pushTwincodeIQ.requestId majorVersion:majorVersion minorVersion:minorVersion receivedTimestamp:twincodeDescriptor.receivedTimestamp];
    
    NSMutableData *data = [onPushTwincodeIQ serializeWithSerializerFactory:self.twinlife.serializerFactory];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultPushTwincode data:data];
}

- (void)processUpdateAnnotationsIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLUpdateAnnotationsIQ *)iq {
    DDLogVerbose(@"%@ processUpdateAnnotationsIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    BOOL modified = NO;
    int64_t receivedTimestamp;
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:iq.descriptorId];

    // Verify that the user can send us twincodes and that we recognize the schema.
    if (descriptor) {
        TLConversationImpl *conversationImpl = connection.conversation;
        NSMutableSet<TLTwincodeOutbound *> *annotatingUsers = [[NSMutableSet alloc] init];
        for (NSUUID *peerTwincodeOutboundId in iq.annotations) {
            NSArray<TLDescriptorAnnotation *> *list = iq.annotations[peerTwincodeOutboundId];
            
            // A twinroom engine can send us back our annotations but we don't want to insert them again.
            if (![peerTwincodeOutboundId isEqual:conversationImpl.twincodeOutboundId]) {
                modified |= [self.serviceProvider setAnnotationsWithDescriptor:descriptor peerTwincodeOutboundId:peerTwincodeOutboundId annotations:list annotatingUsers:annotatingUsers];
            }
        }
        
        if (modified && annotatingUsers.count > 0) {
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onUpdateAnnotationWithConversation:descriptor:annotatingUser:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        for (TLTwincodeOutbound *user in annotatingUsers) {
                            [lDelegate onUpdateAnnotationWithConversation:conversationImpl descriptor:descriptor annotatingUser:user];
                        }
                    });
                }
            }
        }
        receivedTimestamp = 0;
        
    } else {
        // Send him back a receive failure.
        receivedTimestamp = -1;
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdateAnnotationsIQ SERIALIZER_1] requestId:iq.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultUpdateObject iq:onPushIQ];
}

- (void)processUpdateTimestampIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLUpdateTimestampIQ *)updateDescriptorTimestampIQ {
    DDLogVerbose(@"%@ processUpdateTimestampIQWithConnection: %@ updateDescriptorTimestampIQ: %@", LOG_TAG, connection, updateDescriptorTimestampIQ);

    // Return 0 for success and -1 for error (no need for the real timestamp).
    int64_t receivedTimestamp = -1L;
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:updateDescriptorTimestampIQ.descriptorId];
    if (descriptor) {
        TLConversationImpl *conversationImpl = connection.conversation;
        
        id<TLConversation> mainConversation = conversationImpl.mainConversation;
        switch (updateDescriptorTimestampIQ.timestampType) {
            case TLUpdateDescriptorTimestampTypeRead:
                [descriptor setReadTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];

                [self updateWithDescriptor:descriptor conversation:conversationImpl];
                receivedTimestamp = 0;
                break;
                
            case TLUpdateDescriptorTimestampTypeDelete:
                [descriptor setDeletedTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];
                [self.serviceProvider updateDescriptorTimestamps:descriptor];
                
                [self deleteConversationDescriptor:descriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:mainConversation];
                receivedTimestamp = 0;
                break;
                
            case TLUpdateDescriptorTimestampTypePeerDelete:
                [descriptor setPeerDeletedTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];
                [self updateWithDescriptor:descriptor conversation:conversationImpl];
                receivedTimestamp = 0;
                break;
                
            default:
                break;
        }
    }
    
    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdateTimestampIQ SERIALIZER_2] requestId:updateDescriptorTimestampIQ.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultUpdateObject iq:onPushIQ];
}

- (void)processLegacyUpdateDescriptorTimestampIQWithConnection:(nonnull TLConversationConnection *)connection updateDescriptorTimestampIQ:(TLUpdateDescriptorTimestampIQ *)updateDescriptorTimestampIQ {
    DDLogVerbose(@"%@ processLegacyUpdateDescriptorTimestampIQWithConnection: %@ updateDescriptorTimestampIQ: %@", LOG_TAG, connection, updateDescriptorTimestampIQ);
    
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:updateDescriptorTimestampIQ.descriptorId];
    if (descriptor) {
        TLConversationImpl *conversation = connection.conversation;
        id<TLConversation> mainConversation = conversation.mainConversation;
        switch (updateDescriptorTimestampIQ.timestampType) {
            case TLUpdateDescriptorTimestampTypeRead:
                [descriptor setReadTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];

                [self updateWithDescriptor:descriptor conversation:conversation];
                break;
                
            case TLUpdateDescriptorTimestampTypeDelete:
                [descriptor setDeletedTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];
                [self.serviceProvider updateDescriptorTimestamps:descriptor];
                
                [self deleteConversationDescriptor:descriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:mainConversation];
                break;
                
            case TLUpdateDescriptorTimestampTypePeerDelete:
                [descriptor setPeerDeletedTimestamp:[connection adjustedTimeWithTimestamp:updateDescriptorTimestampIQ.timestamp]];
                [self updateWithDescriptor:descriptor conversation:conversation];
                break;
                
            default:
                break;
        }
    }
    
    int majorVersion = updateDescriptorTimestampIQ.majorVersion;
    int minorVersion = updateDescriptorTimestampIQ.minorVersion;
    
    TLOnUpdateDescriptorTimestampIQ *onUpdateDescriptorTimestampIQ = [[TLOnUpdateDescriptorTimestampIQ alloc] initWithId:updateDescriptorTimestampIQ.id from:connection.from to:connection.to requestId:updateDescriptorTimestampIQ.requestId majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL serialized = NO;
    NSException *exception = nil;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    @try {
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:TLPeerConnectionService.LEADING_PADDING start:0 length:(int)TLPeerConnectionService.LEADING_PADDING.length];
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            [TLOnUpdateDescriptorTimestampIQ.SERIALIZER serializeWithSerializerFactory:self.twinlife.serializerFactory encoder:binaryEncoder object:onUpdateDescriptorTimestampIQ];
            
            serialized = YES;
        }
    } @catch (NSException *lException) {
        exception = lException;
    }
    
    if (serialized) {
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultUpdateObject data:data];
    } else {
        [self.twinlife exceptionWithAssertPoint:[TLConversationServiceAssertPoint PROCESS_LEGACY_IQ] exception:exception, [TLAssertValue initWithSubject:connection.conversation.subject], [TLAssertValue initWithPeerConnectionId:connection.peerConnectionId], [TLAssertValue initWithLine:__LINE__], nil];
    }
}

- (void)processInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLInviteGroupIQ *)iq {
    DDLogVerbose(@"%@ processInviteGroupIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    int64_t receivedTimestamp = [self.groupManager processInviteGroupWithConnection:connection invitationDescriptor:iq.invitationDescriptor];

    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onPushIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnInviteGroupIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState receivedTimestamp:receivedTimestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultInviteGroup iq:onPushIQ];
}

- (void)processLegacyInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection inviteGroupIQ:(TLConversationServiceInviteGroupIQ *)inviteGroupIQ {
    DDLogVerbose(@"%@ processLegacyInviteGroupIQWithConnection: %@ inviteGroupIQ: %@", LOG_TAG, connection, inviteGroupIQ);

    [self.groupManager processInviteGroupWithConnection:connection invitationDescriptor:inviteGroupIQ.invitationDescriptor];
    
    int majorVersion = inviteGroupIQ.majorVersion;
    int minorVersion = inviteGroupIQ.minorVersion;
    
    TLConversationServiceOnResultGroupIQ *onInviteGroupIQ = [[TLConversationServiceOnResultGroupIQ alloc] initWithId:inviteGroupIQ.id from:connection.from to:connection.to requestId:inviteGroupIQ.requestId action:ON_INVITE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL withLeadingPadding = connection.withLeadingPadding;
    NSMutableData *data = [onInviteGroupIQ serializeWithSerializerFactory:self.twinlife.serializerFactory withLeadingPadding:withLeadingPadding];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultInviteGroup data:data];
}

- (void)processLegacyRevokeInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection revokeInviteGroupIQ:(TLConversationServiceRevokeInviteGroupIQ *)revokeInviteGroupIQ {
    DDLogVerbose(@"%@ processLegacyRevokeInviteGroupIQWithConnection: %@ revokeInviteGroupIQ: %@", LOG_TAG, connection, revokeInviteGroupIQ);
    
    int majorVersion = revokeInviteGroupIQ.majorVersion;
    int minorVersion = revokeInviteGroupIQ.minorVersion;
    
    [self.groupManager processRevokeInviteGroup:connection.conversation descriptorId:revokeInviteGroupIQ.invitationDescriptor.descriptorId];

    TLConversationServiceOnResultGroupIQ *onRevokeInviteGroupIQ = [[TLConversationServiceOnResultGroupIQ alloc] initWithId:revokeInviteGroupIQ.id from:connection.from to:connection.to requestId:revokeInviteGroupIQ.requestId action:ON_REVOKE_INVITE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL withLeadingPadding = connection.withLeadingPadding;
    NSMutableData *data = [onRevokeInviteGroupIQ serializeWithSerializerFactory:self.twinlife.serializerFactory withLeadingPadding:withLeadingPadding];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultWithdrawInviteGroup data:data];
}

- (void)processJoinGroupIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLJoinGroupIQ *)iq {
    DDLogVerbose(@"%@ processJoinGroupIQWithConnection: %@ joinGroupIQ: %@", LOG_TAG, connection, iq);

    if (iq.memberTwincodeId && iq.publicKey) {
        // Invitation was accepted: get the signed twincode and verify it.
        [self.twincodeOutboundService getSignedTwincodeWithTwincodeId:iq.memberTwincodeId publicKey:iq.publicKey keyIndex:1 secretKey:iq.secretKey trustMethod:TLTrustMethodPeer withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {

            // If we are offline or timed out don't acknowledge the joinIQ: the peer must retry
            // (we must force a close of the P2P connection in case it is still opened).
            if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                [self closeWithPeerConnectionId:connection.peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError];
                return;
            }

            TLGroupJoinResult *joinResult;
            TLConversationImpl *conversationImpl = connection.conversation;
            if (twincodeOutbound) {
                joinResult = [self.groupManager processJoinGroupWithConversation:conversationImpl groupTwincodeId:iq.groupTwincodeId memberTwincode:twincodeOutbound descriptorId:iq.invitationDescriptorId publicKey:iq.publicKey];
            } else {
                [self.groupManager processRejectJoinGroupWithConversation:conversationImpl descriptorId:iq.invitationDescriptorId];
                joinResult = nil;
            }

            int deviceState = [self getDeviceStateWithConnection:connection];
            TLSignatureInfoIQ *signatureInfo = joinResult && joinResult.inviterMemberTwincode ? [[self.twinlife getCryptoService] getSignatureInfoIQWithTwincode:joinResult.inviterMemberTwincode peerTwincode:twincodeOutbound renew:NO] : nil;
            TLOnJoinGroupIQ *onJoinGroupIQ;
            if (signatureInfo) {
                [[self.twinlife getCryptoService] validateSecretWithTwincode:joinResult.inviterMemberTwincode peerTwincodeOutbound:twincodeOutbound];

                onJoinGroupIQ = [[TLOnJoinGroupIQ alloc] initWithSerializer:[TLOnJoinGroupIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState inviterTwincodeId:signatureInfo.twincodeOutboundId inviterPermissions:joinResult.inviterMemberPermissions publicKey:signatureInfo.publicKey secretKey:signatureInfo.secret permissions:joinResult.memberPermissions inviterSalt:nil inviterSignature:joinResult.signature members:joinResult.members];
            } else {
                onJoinGroupIQ = [[TLOnJoinGroupIQ alloc] initWithSerializer:[TLOnJoinGroupIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState inviterTwincodeId:nil inviterPermissions:0 publicKey:nil secretKey:nil permissions:0 inviterSalt:nil inviterSignature:nil members:nil];
            }

            [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultInviteGroup iq:onJoinGroupIQ];
        }];
    } else {
        // Invitation was refused.
        [self.groupManager processRejectJoinGroupWithConversation:connection.conversation descriptorId:iq.invitationDescriptorId];

        int deviceState = [self getDeviceStateWithConnection:connection];
        TLOnJoinGroupIQ *onJoinGroupIQ = [[TLOnJoinGroupIQ alloc] initWithSerializer:[TLOnJoinGroupIQ SERIALIZER_2] requestId:iq.requestId deviceState:deviceState inviterTwincodeId:nil inviterPermissions:0 publicKey:nil secretKey:nil permissions:0 inviterSalt:nil inviterSignature:nil members:nil];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultInviteGroup iq:onJoinGroupIQ];
    }
}

- (void)processLegacyJoinGroupIQWithConnection:(nonnull TLConversationConnection *)connection joinGroupIQ:(TLConversationServiceJoinGroupIQ *)joinGroupIQ {
    DDLogVerbose(@"%@ processLegacyJoinGroupIQWithConnection: %@ joinGroupIQ: %@", LOG_TAG, connection, joinGroupIQ);
    
    int majorVersion = joinGroupIQ.majorVersion;
    int minorVersion = joinGroupIQ.minorVersion;

    TLDescriptorId *descriptorId;
    TLInvitationDescriptorStatusType status;
    if (joinGroupIQ.invitationDescriptor) {
        descriptorId = joinGroupIQ.invitationDescriptor.descriptorId;
        status = joinGroupIQ.invitationDescriptor.status;
    } else {
        descriptorId = nil;
        status = TLInvitationDescriptorStatusTypeAccepted;
    }
    if (joinGroupIQ.memberTwincodeId && status == TLInvitationDescriptorStatusTypeAccepted) {
        // Invitation was accepted: get the twincode.
        [self.twincodeOutboundService getTwincodeWithTwincodeId:joinGroupIQ.memberTwincodeId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {

            // If we are offline or timed out don't acknowledge the joinIQ: the peer must retry
            // (we must force a close of the P2P connection in case it is still opened).
            if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                [self closeWithPeerConnectionId:connection.peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError];
                return;
            }

            TLGroupJoinResult *joinResult;
            TLConversationImpl *conversation = connection.conversation;
            if (!twincodeOutbound) {
                // New member twincode does not exist, reject the invitation if we have one.
                if (descriptorId) {
                    [self.groupManager processRejectJoinGroupWithConversation:conversation descriptorId:descriptorId];
                }
                joinResult = nil;

            } else if (descriptorId) {
                // Accept the invitation.
                joinResult = [self.groupManager processJoinGroupWithConversation:conversation groupTwincodeId:joinGroupIQ.groupTwincodeId memberTwincode:twincodeOutbound descriptorId:descriptorId publicKey:nil];
            } else {
                joinResult = [self.groupManager processJoinGroupWithGroupTwincodeId:joinGroupIQ.groupTwincodeId memberTwincode:twincodeOutbound memberPermissions:joinGroupIQ.permissions];
            }

            TLConversationServiceOnResultJoinGroupIQ *onJoinGroupIQ;
            if (joinResult) {
                [joinResult.members addObject:[[TLOnJoinGroupMemberInfo alloc] initWithTwincodeId:joinResult.inviterMemberTwincode.uuid publicKey:nil permissions:joinResult.inviterMemberPermissions]];
                onJoinGroupIQ = [[TLConversationServiceOnResultJoinGroupIQ alloc] initWithId:joinGroupIQ.id from:conversation.from to:conversation.to requestId:joinGroupIQ.requestId action:ON_JOIN_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion status:TLInvitationDescriptorStatusTypeJoined permissions:joinResult.memberPermissions members:joinResult.members];
            } else {
                onJoinGroupIQ = [[TLConversationServiceOnResultJoinGroupIQ alloc] initWithId:joinGroupIQ.id from:conversation.from to:conversation.to requestId:joinGroupIQ.requestId action:ON_JOIN_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion status:TLInvitationDescriptorStatusTypeWithdrawn permissions:0 members:nil];
            }
            
            NSMutableData *data = [onJoinGroupIQ serializeWithSerializerFactory:self.twinlife.serializerFactory];
            [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultJoinGroup data:data];
        }];
    } else {
        // Invitation was refused.
        if (descriptorId) {
            [self.groupManager processRejectJoinGroupWithConversation:connection.conversation descriptorId:descriptorId];
        }

        TLConversationServiceOnResultJoinGroupIQ *onJoinGroupIQ = [[TLConversationServiceOnResultJoinGroupIQ alloc] initWithId:joinGroupIQ.id from:connection.from to:connection.to requestId:joinGroupIQ.requestId action:ON_JOIN_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion status:TLInvitationDescriptorStatusTypeWithdrawn permissions:0 members:nil];
        
        NSMutableData *data = [onJoinGroupIQ serializeWithSerializerFactory:self.twinlife.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultJoinGroup data:data];
    }
}

- (void)processLegacyLeaveGroupIQWithConnection:(nonnull TLConversationConnection *)connection leaveGroupIQ:(TLConversationServiceLeaveGroupIQ *)leaveGroupIQ {
    DDLogVerbose(@"%@ processLegacyLeaveGroupIQWithConnection: %@ leaveGroupIQ: %@", LOG_TAG, connection, leaveGroupIQ);
    
    int majorVersion = leaveGroupIQ.majorVersion;
    int minorVersion = leaveGroupIQ.minorVersion;

    [self.groupManager processLeaveGroupWithGroupTwincodeId:leaveGroupIQ.groupTwincodeId memberTwincodeId:leaveGroupIQ.memberTwincodeId];

    TLConversationServiceOnResultGroupIQ *onLeaveGroupIQ = [[TLConversationServiceOnResultGroupIQ alloc] initWithId:leaveGroupIQ.id from:connection.from to:connection.to requestId:leaveGroupIQ.requestId action:ON_LEAVE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL withLeadingPadding = connection.withLeadingPadding;
    NSMutableData *data = [onLeaveGroupIQ serializeWithSerializerFactory:self.twinlife.serializerFactory withLeadingPadding:withLeadingPadding];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultLeaveGroup data:data];
}

- (void)processUpdatePermissionsIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLUpdatePermissionsIQ *)updatePermissionsIQ {
    DDLogVerbose(@"%@ processUpdatePermissionsIQWithConnection: %@ updateGroupMemberIQ: %@", LOG_TAG, connection, updatePermissionsIQ);

    [self.groupManager processUpdateGroupMemberWithConversation:connection.conversation groupTwincodeId:updatePermissionsIQ.groupTwincodeId memberTwincodeId:updatePermissionsIQ.memberTwincodeId permissions:updatePermissionsIQ.permissions];

    int deviceState = [self getDeviceStateWithConnection:connection];
    TLOnPushIQ *onUpdatePermissionsIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnUpdatePermissionsIQ SERIALIZER_1] requestId:updatePermissionsIQ.requestId deviceState:deviceState receivedTimestamp:0];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultInviteGroup iq:onUpdatePermissionsIQ];
}

- (void)processLegacyUpdateGroupMemberIQWithConnection:(nonnull TLConversationConnection *)connection updateGroupMemberIQ:(TLConversationServiceUpdateGroupMemberIQ *)updateGroupMemberIQ {
    DDLogVerbose(@"%@ processLegacyUpdateGroupMemberIQWithConnection: %@ updateGroupMemberIQ: %@", LOG_TAG, connection, updateGroupMemberIQ);
    
    int majorVersion = updateGroupMemberIQ.majorVersion;
    int minorVersion = updateGroupMemberIQ.minorVersion;

    [self.groupManager processUpdateGroupMemberWithConversation:connection.conversation groupTwincodeId:updateGroupMemberIQ.groupTwincodeId memberTwincodeId:updateGroupMemberIQ.memberTwincodeId permissions:updateGroupMemberIQ.permissions];

    TLConversationServiceOnResultGroupIQ *onUpdateGroupMemberIQ = [[TLConversationServiceOnResultGroupIQ alloc] initWithId:updateGroupMemberIQ.id from:connection.from to:connection.to requestId:updateGroupMemberIQ.requestId action:ON_UPDATE_GROUP_MEMBER_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    BOOL withLeadingPadding = connection.withLeadingPadding;
    NSMutableData *data = [onUpdateGroupMemberIQ serializeWithSerializerFactory:self.twinlife.serializerFactory withLeadingPadding:withLeadingPadding];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqResultUpdateGroupMember data:data];
}

- (void)processSynchronizeIQWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId iq:(nonnull TLSynchronizeIQ *)iq {
    DDLogVerbose(@"%@ processSynchronizeIQWithPeerConnection: %@ iq: %@", LOG_TAG, peerConnectionId, iq);
    
    TLConversationConnection *connection = [self preparePeerConversationWithPeerConnectionId:peerConnectionId peerTwincodeOutboundId:iq.twincodeOutboundId peerResourceId:iq.resourceId];

    if (!connection) {
        return;
    }

    int deviceState = [self getDeviceStateWithConnection:connection];
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    TLOnSynchronizeIQ *onSynchronizeIQ = [[TLOnSynchronizeIQ alloc] initWithSerializer:[TLOnSynchronizeIQ SERIALIZER_1] requestId:iq.requestId deviceState:deviceState timestamp:now senderTimestamp:iq.timestamp];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultSynchronize iq:onSynchronizeIQ];
}

- (void)processOnSynchronizeIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnSynchronizeIQ *)iq {
    DDLogVerbose(@"%@ processOnSynchronizeIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    [connection adjustTimeWithPeerTime:iq.timestamp startTime:iq.senderTimestamp];
    TLConversationServiceOperation *firstOperation = [self.scheduler startOperationsWithConnection:connection state:TLConversationStateOpen];
    if (firstOperation) {
        [self sendOperationInternalWithConnection:connection operation:firstOperation];
    }
}

- (void)processOnResetConversationIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnResetConversationIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLResetConversationOperation class]])  {
            TLResetConversationOperation *resetConversationOperation = (TLResetConversationOperation *)operation;
            TLClearDescriptor *clearDescriptor = resetConversationOperation.clearDescriptor;
            
            // Update the received timestamp only the first time.
            if (clearDescriptor && clearDescriptor.receivedTimestamp <= 0) {
                [clearDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:iq.receivedTimestamp]];

                [self updateWithDescriptor:clearDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnResetConversationIQWithConnection:(nonnull TLConversationConnection *)connection onResetConversationIQ:(TLConversationServiceOnResetConversationIQ *)onResetConversationIQ {
    DDLogVerbose(@"%@ processLegacyOnResetConversationIQWithConnection: %@ onResetConversationIQ: %@", LOG_TAG, connection, onResetConversationIQ);
    
    TLConversationImpl *conversationImpl = connection.conversation;
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:conversationImpl requestId:onResetConversationIQ.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLResetConversationOperation class]])  {
            TLResetConversationOperation *resetConversationOperation = (TLResetConversationOperation *)operation;
            TLClearDescriptor *clearDescriptor = resetConversationOperation.clearDescriptor;
            
            // Update the received timestamp only the first time.  Since the peer is using an old
            // version, we don't know the receive timestamp and use our local time.
            if (clearDescriptor && clearDescriptor.receivedTimestamp <= 0) {
                [clearDescriptor setReceivedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];

                [self updateWithDescriptor:clearDescriptor conversation:conversationImpl];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushCommandIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)onPushCommandIQ {
    DDLogVerbose(@"%@ processOnPushCommandIQWithConnection: %@ onPushCommandIQ: %@", LOG_TAG, connection, onPushCommandIQ);

    connection.peerDeviceState = (onPushCommandIQ.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationImpl *conversationImpl = connection.conversation;
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:conversationImpl requestId:onPushCommandIQ.requestId];
    if (operation && [operation isKindOfClass:[TLPushCommandOperation class]])  {
        TLPushCommandOperation *pushCommandOperation = (TLPushCommandOperation *)operation;
        TLTransientObjectDescriptor *commandDescriptor = pushCommandOperation.commandDescriptor;
        [commandDescriptor setReceivedTimestamp:onPushCommandIQ.receivedTimestamp];
            
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:(TLDescriptor*)commandDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
                });
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushCommandIQWithConnection:(nonnull TLConversationConnection *)connection onPushCommandIQ:(TLConversationServiceOnPushCommandIQ *)onPushCommandIQ {
    DDLogVerbose(@"%@ processLegacyOnPushCommandIQWithConnection: %@ onPushCommandIQ: %@", LOG_TAG, connection, onPushCommandIQ);
    
    TLConversationImpl *conversationImpl = connection.conversation;
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:conversationImpl requestId:onPushCommandIQ.requestId];
    if (operation && [operation isKindOfClass:[TLPushCommandOperation class]])  {
        TLPushCommandOperation *pushCommandOperation = (TLPushCommandOperation *)operation;
        TLTransientObjectDescriptor *commandDescriptor = pushCommandOperation.commandDescriptor;
        [commandDescriptor setReceivedTimestamp:onPushCommandIQ.receivedTimestamp];
            
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:(TLDescriptor*)commandDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
                });
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushObjectIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnPushObjectIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationImpl *conversationImpl = connection.conversation;
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:conversationImpl requestId:iq.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushObjectOperation class]])  {
            TLPushObjectOperation *pushObjectOperation = (TLPushObjectOperation *)operation;
            TLObjectDescriptor *objectDescriptor = pushObjectOperation.objectDescriptor;
            
            // Update the received timestamp only the first time.
            if (objectDescriptor && objectDescriptor.receivedTimestamp <= 0) {
                [objectDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:iq.receivedTimestamp]];

                [self updateWithDescriptor:objectDescriptor conversation:conversationImpl];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushObjectIQWithConnection:(nonnull TLConversationConnection *)connection onPushObjectIQ:(TLConversationServiceOnPushObjectIQ *)onPushObjectIQ {
    DDLogVerbose(@"%@ processLegacyOnPushObjectIQWithConnection: %@ onPushObjectIQ: %@", LOG_TAG, connection, onPushObjectIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onPushObjectIQ.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushObjectOperation class]])  {
            TLPushObjectOperation *pushObjectOperation = (TLPushObjectOperation *)operation;
            TLObjectDescriptor *objectDescriptor = pushObjectOperation.objectDescriptor;
            
            // Update the received timestamp only the first time.
            if (objectDescriptor && objectDescriptor.receivedTimestamp <= 0) {
                [objectDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:onPushObjectIQ.receivedTimestamp]];
                [self.serviceProvider updateDescriptorTimestamps:objectDescriptor];
            }

            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:(TLDescriptor*)objectDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
                    });
                }
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushFileIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnPushFileIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushFileOperation class]])  {
            TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
            TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
            if (fileDescriptor) {
                if (pushFileOperation.chunkStart == PUSH_FILE_OPERATION_NOT_INITIALIZED) {
                    // We keep the same request id on the operation because we are ready to send the data chunks in batch mode.
                    pushFileOperation.chunkStart = 0;
                    [self.serviceProvider updateFileOperation:pushFileOperation];
                    [pushFileOperation executeWithConnection:connection];
                    return;
                }
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushFileIQWithConnection:(nonnull TLConversationConnection *)connection onPushFileIQ:(TLConversationServiceOnPushFileIQ *)onPushFileIQ {
    DDLogVerbose(@"%@ processLegacyOnPushFileIQWithConnection: %@ onPushFileIQ: %@", LOG_TAG, connection, onPushFileIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onPushFileIQ.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushFileOperation class]])  {
            TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
            TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
            if (fileDescriptor) {
                if (pushFileOperation.chunkStart == PUSH_FILE_OPERATION_NOT_INITIALIZED) {
                    [pushFileOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
                    pushFileOperation.chunkStart = 0;
                    [self.serviceProvider updateFileOperation:pushFileOperation];
                    [self executeOperationWithConversation:connection.conversation];
                    return;
                }
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushFileChunkIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushFileChunkIQ *)iq {
    DDLogVerbose(@"%@ processOnPushFileChunkIQWithConversation: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    
    if (operation) {
        BOOL done = false;
        if ([operation isKindOfClass:[TLPushFileOperation class]])  {
            TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
            TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
            if (fileDescriptor) {
                if (iq.nextChunkStart < fileDescriptor.length) {
                    [connection updateEstimatedRttWithTimestamp:iq.senderTimestamp];

                    // We keep the same request id on the operation and continue sending more chunks.
                    pushFileOperation.chunkStart = iq.nextChunkStart;
                    [pushFileOperation executeWithConnection:connection];
                    return;
                    
                } else {

                    // Update the received timestamp only the first time.
                    if (fileDescriptor.receivedTimestamp <= 0) {
                        int64_t timestamp = [connection adjustedTimeWithTimestamp:iq.receivedTimestamp];
                        [fileDescriptor setUpdatedTimestamp:timestamp];
                        [fileDescriptor setReceivedTimestamp:timestamp];
                    }

                    [self updateWithDescriptor:fileDescriptor conversation:connection.conversation];

                    done = true;
                }
            }
            // TBD - removed file
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushFileChunkIQWithConnection:(nonnull TLConversationConnection *)connection onPushFileChunkIQ:(TLConversationServiceOnPushFileChunkIQ *)onPushFileChunkIQ {
    DDLogVerbose(@"%@ processLegacyOnPushFileChunkIQWithConnection: %@ onPushFileChunkIQ: %@", LOG_TAG, connection, onPushFileChunkIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onPushFileChunkIQ.requestId];
    
    if (operation) {
        BOOL done = false;
        if ([operation isKindOfClass:[TLPushFileOperation class]])  {
            TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
            TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
            if (fileDescriptor) {
                if (onPushFileChunkIQ.nextChunkStart < fileDescriptor.length) {
                    [pushFileOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
                    pushFileOperation.chunkStart = onPushFileChunkIQ.nextChunkStart;
                    [self.serviceProvider updateFileOperation:pushFileOperation];
                    [pushFileOperation executeWithConnection:connection];
                    return;
                    
                } else {
                    // Update the received timestamp only the first time.
                    if (fileDescriptor.receivedTimestamp <= 0) {
                        int64_t timestamp = [connection adjustedTimeWithTimestamp:onPushFileChunkIQ.receivedTimestamp];
                        [fileDescriptor setUpdatedTimestamp:timestamp];
                        [fileDescriptor setReceivedTimestamp:timestamp];
                    }
                    [self.serviceProvider updateDescriptorTimestamps:fileDescriptor];

                    for (id delegate in self.delegates) {
                        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                            id<TLConversationServiceDelegate> lDelegate = delegate;
                            dispatch_async([self.twinlife twinlifeQueue], ^{
                                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation descriptor:fileDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
                            });
                        }
                    }
                    done = true;
                }
            }
            // TBD - removed file
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnUpdateObjectIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnUpdateObjectIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationImpl *conversationImpl = connection.conversation;
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:conversationImpl requestId:iq.requestId];
    if (operation && [operation isKindOfClass:[TLUpdateDescriptorOperation class]])  {
        TLUpdateDescriptorOperation *updateDescriptorOperation = (TLUpdateDescriptorOperation *)operation;
        TLDescriptor *descriptor = updateDescriptorOperation.descriptorImpl;
        
        // Update the received timestamp only the first time.
        if (descriptor && descriptor.receivedTimestamp < descriptor.updatedTimestamp
            && descriptor.updatedTimestamp > descriptor.createdTimestamp) {
            [descriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:iq.receivedTimestamp]];
            
            [self updateWithDescriptor:descriptor conversation:conversationImpl];
        }
    }
 
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushGeolocationIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnPushGeolocationIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushGeolocationOperation class]])  {
            TLPushGeolocationOperation *pushGeolocationOperation = (TLPushGeolocationOperation *)operation;
            TLGeolocationDescriptor *geolocationDescriptor = pushGeolocationOperation.geolocationDescriptor;
            
            // Update the received timestamp only the first time.
            if (geolocationDescriptor && geolocationDescriptor.receivedTimestamp <= 0) {
                [geolocationDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:iq.receivedTimestamp]];
                [self updateWithDescriptor:geolocationDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushGeolocationIQWithConnection:(nonnull TLConversationConnection *)connection onPushGeolocationIQ:(TLConversationServiceOnPushGeolocationIQ *)onPushGeolocationIQ {
    DDLogVerbose(@"%@ processLegacyOnPushGeolocationIQWithConnection: %@ onPushGeolocationIQ: %@", LOG_TAG, connection, onPushGeolocationIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onPushGeolocationIQ.requestId];
    if (operation) {
        if ([operation isKindOfClass:[TLPushGeolocationOperation class]])  {
            TLPushGeolocationOperation *pushGeolocationOperation = (TLPushGeolocationOperation *)operation;
            TLGeolocationDescriptor *geolocationDescriptor = pushGeolocationOperation.geolocationDescriptor;
            
            // Update the received timestamp only the first time.
            if (geolocationDescriptor && geolocationDescriptor.receivedTimestamp <= 0) {
                [geolocationDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:onPushGeolocationIQ.receivedTimestamp]];
                [self updateWithDescriptor:geolocationDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnPushTwincodeIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnPushTwincodeIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    if (operation) {
        
        if ([operation isKindOfClass:[TLPushTwincodeOperation class]]) {
            TLPushTwincodeOperation *pushTwincodeOperation = (TLPushTwincodeOperation *)operation;
            TLTwincodeDescriptor *twincodeDescriptor = pushTwincodeOperation.twincodeDescriptor;
            
            // Update the received timestamp only the first time.
            if (twincodeDescriptor && twincodeDescriptor.receivedTimestamp <= 0) {
                [twincodeDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:iq.receivedTimestamp]];
                [self updateWithDescriptor:twincodeDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnPushTwincodeIQWithConnection:(nonnull TLConversationConnection *)connection onPushTwincodeIQ:(TLConversationServiceOnPushTwincodeIQ *)onPushTwincodeIQ {
    DDLogVerbose(@"%@ processLegacyOnPushTwincodeIQWithConnection: %@ onPushTwincodeIQ: %@", LOG_TAG, connection, onPushTwincodeIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onPushTwincodeIQ.requestId];
    if (operation) {
        
        if ([operation isKindOfClass:[TLPushTwincodeOperation class]]) {
            TLPushTwincodeOperation *pushTwincodeOperation = (TLPushTwincodeOperation *)operation;
            TLTwincodeDescriptor *twincodeDescriptor = pushTwincodeOperation.twincodeDescriptor;
            
            // Update the received timestamp only the first time.
            if (twincodeDescriptor && twincodeDescriptor.receivedTimestamp <= 0) {
                [twincodeDescriptor setReceivedTimestamp:[connection adjustedTimeWithTimestamp:onPushTwincodeIQ.receivedTimestamp]];
                [self updateWithDescriptor:twincodeDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnUpdateAnnotationsIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnUpdateAnnotationsIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnUpdateTimestampIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)onUpdateDescriptorTimestampIQ {
    DDLogVerbose(@"%@ processOnUpdateTimestampIQWithConnection: %@ onUpdateDescriptorTimestampIQ: %@", LOG_TAG, connection, onUpdateDescriptorTimestampIQ);

    connection.peerDeviceState = (onUpdateDescriptorTimestampIQ.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onUpdateDescriptorTimestampIQ.requestId];
    if (operation && [operation isKindOfClass:[TLUpdateDescriptorTimestampOperation class]]) {
        TLUpdateDescriptorTimestampOperation  *updateDescriptorTimestampOperation = (TLUpdateDescriptorTimestampOperation *)operation;
        if (updateDescriptorTimestampOperation.timestampType == TLUpdateDescriptorTimestampTypeDelete) {
            TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:updateDescriptorTimestampOperation.updateDescriptorId];
            if (descriptor) {
                if (descriptor.peerDeletedTimestamp == 0) {
                    [descriptor setPeerDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
                    [self.serviceProvider updateDescriptorTimestamps:descriptor];
                }
                
                [self deleteConversationDescriptor:descriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnUpdateDescriptorTimestampIQWithConnection:(nonnull TLConversationConnection *)connection onUpdateDescriptorTimestampIQ:(TLOnUpdateDescriptorTimestampIQ *)onUpdateDescriptorTimestampIQ {
    DDLogVerbose(@"%@ processLegacyOnUpdateDescriptorTimestampIQWithConnection: %@ onUpdateDescriptorTimestampIQ: %@", LOG_TAG, connection, onUpdateDescriptorTimestampIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onUpdateDescriptorTimestampIQ.requestId];
    if (operation && [operation isKindOfClass:[TLUpdateDescriptorTimestampOperation class]]) {
        TLUpdateDescriptorTimestampOperation  *updateDescriptorTimestampOperation = (TLUpdateDescriptorTimestampOperation *)operation;
        if (updateDescriptorTimestampOperation.timestampType == TLUpdateDescriptorTimestampTypeDelete) {
            TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:updateDescriptorTimestampOperation.updateDescriptorId];
            if (descriptor) {
                if (descriptor.peerDeletedTimestamp == 0) {
                    [descriptor setPeerDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
                    [self.serviceProvider updateDescriptorTimestamps:descriptor];
                }
                
                [self deleteConversationDescriptor:descriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnInviteGroupIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:iq.requestId];
    if (operation) {
        
        if ([operation isKindOfClass:[TLGroupInviteOperation class]]) {
            TLGroupInviteOperation *groupOperation = (TLGroupInviteOperation *)operation;
            TLInvitationDescriptor *invitationDescriptor = groupOperation.invitationDescriptor;
            
            // Update the invitation descriptor to mark is as received.
            if (invitationDescriptor) {
                invitationDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
                [self updateWithDescriptor:invitationDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection onInviteGroupIQ:(TLConversationServiceOnResultGroupIQ *)onInviteGroupIQ {
    DDLogVerbose(@"%@ processLegacyOnInviteGroupIQWithConnection: %@ onInviteGroupIQ: %@", LOG_TAG, connection, onInviteGroupIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onInviteGroupIQ.requestId];
    if (operation) {
        
        if ([operation isKindOfClass:[TLGroupInviteOperation class]]) {
            TLGroupInviteOperation *groupOperation = (TLGroupInviteOperation *)operation;
            TLInvitationDescriptor *invitationDescriptor = groupOperation.invitationDescriptor;
            
            // Update the invitation descriptor to mark is as received.
            if (invitationDescriptor) {
                invitationDescriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
                [self updateWithDescriptor:invitationDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnRevokeInviteGroupIQWithConnection:(nonnull TLConversationConnection *)connection onRevokeInviteGroupIQ:(TLConversationServiceOnResultGroupIQ *)onRevokeInviteGroupIQ {
    DDLogVerbose(@"%@ processLegacyOnRevokeInviteGroupIQWithConnection: %@ onRevokeInviteGroupIQ: %@", LOG_TAG, connection, onRevokeInviteGroupIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onRevokeInviteGroupIQ.requestId];
    if (operation) {
        
        if ([operation isKindOfClass:[TLGroupInviteOperation class]]) {
            TLGroupInviteOperation *groupOperation = (TLGroupInviteOperation *)operation;
            TLInvitationDescriptor *invitationDescriptor = groupOperation.invitationDescriptor;
            
            // Update the invitation descriptor: mark is as deleted for the observers and remove it from the database.
            if (invitationDescriptor) {
                invitationDescriptor.peerDeletedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
                [self deleteConversationDescriptor:invitationDescriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnJoinGroupIQWithConnection:(nonnull TLConversationConnection *)connection iq:(TLOnJoinGroupIQ *)onJoinGroupIQ {
    DDLogVerbose(@"%@ processOnJoinGroupIQWithConnection: %@ onJoinGroupIQ: %@", LOG_TAG, connection, onJoinGroupIQ);

    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onJoinGroupIQ.requestId];
    if (operation && [operation isKindOfClass:[TLGroupJoinOperation class]]) {
        TLGroupJoinOperation *groupOperation = (TLGroupJoinOperation *)operation;
        if (onJoinGroupIQ.inviterTwincodeId && onJoinGroupIQ.publicKey) {
            [self.twincodeOutboundService getSignedTwincodeWithTwincodeId:onJoinGroupIQ.inviterTwincodeId publicKey:onJoinGroupIQ.publicKey keyIndex:1 secretKey:onJoinGroupIQ.secretKey trustMethod:TLTrustMethodPeer withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                
                // If we are offline or timed out don't finish the operation: we must retry it.
                // (we must force a close of the P2P connection in case it is still opened).
                if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                    [self closeWithPeerConnectionId:connection.peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError];
                    return;
                }

                if (twincodeOutbound) {
                    [self.groupManager processOnJoinGroupWithConversation:connection.conversation groupTwincodeId:groupOperation.groupTwincodeId invitationDescriptor:groupOperation.invitationDescriptor inviterTwincode:twincodeOutbound inviterPermissions:onJoinGroupIQ.inviterPermissions members:onJoinGroupIQ.members permissions:onJoinGroupIQ.permissions signature:onJoinGroupIQ.inviterSignature];
                } else if (groupOperation.invitationDescriptor) {
                    [self.groupManager processOnJoinGroupWithdrawnWithInvitation:groupOperation.invitationDescriptor];
                }
                [self.scheduler finishOperation:operation connection:connection];
            }];
        } else {
            if (groupOperation.invitationDescriptor) {
                [self.groupManager processOnJoinGroupWithdrawnWithInvitation:groupOperation.invitationDescriptor];
            }
            [self.scheduler finishOperation:operation connection:connection];
        }
    } else {
        [self.scheduler finishOperation:operation connection:connection];
    }
}

- (void)processLegacyOnJoinGroupIQWithConnection:(nonnull TLConversationConnection *)connection onJoinGroupIQ:(TLConversationServiceOnResultJoinGroupIQ *)onJoinGroupIQ {
    DDLogVerbose(@"%@ processLegacyOnJoinGroupIQWithConnection: %@ onJoinGroupIQ: %@", LOG_TAG, connection, onJoinGroupIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onJoinGroupIQ.requestId];
    if (operation && [operation isKindOfClass:[TLGroupJoinOperation class]]) {
        TLGroupJoinOperation *groupOperation = (TLGroupJoinOperation *)operation;
        if (onJoinGroupIQ.status == TLInvitationDescriptorStatusTypeJoined) {
            [self.groupManager processOnJoinGroupWithConversation:connection.conversation groupTwincodeId:groupOperation.groupTwincodeId invitationDescriptor:groupOperation.invitationDescriptor inviterTwincode:nil inviterPermissions:0 members:onJoinGroupIQ.members permissions:onJoinGroupIQ.permissions signature:nil];
        } else {
            if (groupOperation.invitationDescriptor) {
                [self.groupManager processOnJoinGroupWithdrawnWithInvitation:groupOperation.invitationDescriptor];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnLeaveGroupIQWithConnection:(nonnull TLConversationConnection *)connection onLeaveGroupIQ:(TLConversationServiceOnResultGroupIQ *)onLeaveGroupIQ {
    DDLogVerbose(@"%@ processLegacyOnLeaveGroupIQWithConnection: %@ onLeaveGroupIQ: %@", LOG_TAG, connection, onLeaveGroupIQ);
    
    // The leave operation has finished and the peer has removed the member from its group.
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onLeaveGroupIQ.requestId];
    if (operation && [operation isKindOfClass:[TLGroupLeaveOperation class]]) {
        TLGroupLeaveOperation *groupOperation = (TLGroupLeaveOperation *)operation;
        [self.groupManager processOnLeaveGroupWithGroupTwincodeId:groupOperation.groupTwincodeId memberTwincodeId:groupOperation.memberTwincodeId peerTwincodeId:connection.conversation.peerTwincodeOutboundId];
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnUpdatePermissionsIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)onUpdateGroupMemberIQ {
    DDLogVerbose(@"%@ processOnUpdatePermissionsIQWithConnection: %@ onUpdateGroupMemberIQ: %@", LOG_TAG, connection, onUpdateGroupMemberIQ);

    // The update group member operation has finished.
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onUpdateGroupMemberIQ.requestId];
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processLegacyOnUpdateGroupMemberIQWithConnection:(nonnull TLConversationConnection *)connection onUpdateGroupMemberIQ:(TLConversationServiceOnResultGroupIQ *)onUpdateGroupMemberIQ {
    DDLogVerbose(@"%@ processLegacyOnUpdateGroupMemberIQWithConnection: %@ onUpdateGroupMemberIQ: %@", LOG_TAG, connection, onUpdateGroupMemberIQ);
    
    // The update group member operation has finished.
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onUpdateGroupMemberIQ.requestId];
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processSignatureInfoIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLSignatureInfoIQ *)signatureInfoIQ {
    DDLogVerbose(@"%@ processSignatureInfoIQWithConnection: %@ signatureInfoIQ: %@", LOG_TAG, connection, signatureInfoIQ);

    // Accept the signature info only for the peer conversation twincode.
    NSUUID *peerConnectionId = connection.peerConnectionId;
    TLConversationImpl *conversation = connection.conversation;
    TLTwincodeOutbound *twincodeOutbound = conversation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    TLPeerConnectionServiceSdpEncryptionStatus encryptionStatus = [self.peerConnectionService sdpEncryptionStatusWithPeerConnectionId:peerConnectionId];
    if (!peerTwincodeOutbound || ![signatureInfoIQ.twincodeOutboundId isEqual:peerTwincodeOutbound.uuid]) {
        [self.twinlife assertionWithAssertPoint:[TLConversationServiceAssertPoint EXCEPTION], [TLAssertValue initWithPeerConnectionId:peerConnectionId], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], [TLAssertValue initWithTwincodeOutbound:peerTwincodeOutbound], nil];
        return;
    }

    // If the SDPs are encrypted, this is a renew and we must only save the new secret.
    // We must not call the onSignatureInfoWithConversation delegate because this will force a
    // trust of the twincode: if it's not trusted, the relation was established with public keys
    // and the user must use the QR-code or video certification process.
    if (encryptionStatus != TLPeerConnectionServiceSdpEncryptionStatusNone) {
        
        [[self.twinlife getCryptoService] saveSecretKeyWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound keyIndex:signatureInfoIQ.keyIndex secretKey:signatureInfoIQ.secret];

        int deviceState = [self getDeviceStateWithConnection:connection];
        TLOnPushIQ *onSignatureInfoIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnSignatureInfoIQ SERIALIZER] requestId:signatureInfoIQ.requestId deviceState:deviceState receivedTimestamp:0];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultSignatureInfo iq:onSignatureInfoIQ];
        return;
    }

    [self.twinlife.twincodeOutboundService getSignedTwincodeWithTwincodeId:signatureInfoIQ.twincodeOutboundId publicKey:signatureInfoIQ.publicKey keyIndex:signatureInfoIQ.keyIndex secretKey:signatureInfoIQ.secret trustMethod:TLTrustMethodAuto withBlock:^(TLBaseServiceErrorCode result, TLTwincodeOutbound * _Nullable signedTwincode) {
        DDLogVerbose(@"%@ Got signed twincode %@ result: %d", LOG_TAG, signedTwincode, result);
        
        if (result != TLBaseServiceErrorCodeSuccess || !signedTwincode) {
            return;
        }
        
        // Only one of the two peer marks the twincode as trusted: this allows both peers
        // to validate their relation either with QR-code or through the video call.
        if ([signatureInfoIQ.twincodeOutboundId compareTo:conversation.twincodeOutboundId] < 0) {
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onSignatureInfoWithConversation:signedTwincode:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onSignatureInfoWithConversation:conversation signedTwincode:signedTwincode];
                    });
                }
            }
        }

        int deviceState = [self getDeviceStateWithConnection:connection];
        TLOnPushIQ *onSignatureInfoIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLOnSignatureInfoIQ SERIALIZER] requestId:signatureInfoIQ.requestId deviceState:deviceState receivedTimestamp:0];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultSignatureInfo iq:onSignatureInfoIQ];
    }];
}

- (void)processOnSignatureInfoIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processOnSignatureInfoIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);
    
    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;
    connection.synchronizeKeys = NO;
    TLConversationImpl *conversation = connection.conversation;
    TLTwincodeOutbound *twincodeOutbound = conversation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    if (twincodeOutbound && peerTwincodeOutbound) {
        [[self.twinlife getCryptoService] validateSecretWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound];
    }

    // Send a last OnPushIQ to propagate our new device state to the peer and acknowledge our validateSecrets().
    int deviceState = [self getDeviceStateWithConnection:connection];
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    TLOnPushIQ *ackIQ = [[TLOnPushIQ alloc] initWithSerializer:[TLAckSignatureInfoIQ SERIALIZER] requestId:iq.requestId deviceState:deviceState receivedTimestamp:now];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqResultSynchronize iq:ackIQ];
}

- (void)processAckSignatureInfoIQWithConnection:(nonnull TLConversationConnection *)connection iq:(nonnull TLOnPushIQ *)iq {
    DDLogVerbose(@"%@ processAckSignatureInfoIQWithConnection: %@ iq: %@", LOG_TAG, connection, iq);
    
    connection.peerDeviceState = (iq.deviceState & DEVICE_STATE_MASK) | DEVICE_STATE_VALID;

    TLConversationImpl *conversation = connection.conversation;
    TLTwincodeOutbound *twincodeOutbound = conversation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    if (twincodeOutbound && peerTwincodeOutbound
        && (![twincodeOutbound isEncrypted] || ![peerTwincodeOutbound isEncrypted])) {
        [self.twincodeOutboundService associateTwincodes:twincodeOutbound previousPeerTwincode:nil peerTwincode:peerTwincodeOutbound];
    }
}

- (void)processOnServiceErrorIQWithConnection:(nonnull TLConversationConnection *)connection onServiceErrorIQ:(nonnull TLServiceErrorIQ *)onServiceErrorIQ {
    DDLogVerbose(@"%@ processOnServiceErrorIQWithConnection: %@ onServiceErrorIQ: %@", LOG_TAG, connection, onServiceErrorIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getOperationWithConversation:connection.conversation requestId:onServiceErrorIQ.requestId];
    if (operation) {
        
        // Handle the error according to the operation:
        // - for a PUSH_FILE, mark the descriptor as being not sent (can happen if there not not enough space, storage constraints, ...),
        // - for a PUSH_OBJECT, mark the descriptor as being not sent (should not happen except when a bug is there),
        // - for SYNCHRONIZE_CONVERSATION, RESET_CONVERSATION was can safely ignore (or, close the P2P connection?),
        // - for a PUSH_TRANSIENT_OBJECT we can ignore,
        // - for a UPDATE_DESCRIPTOR_TIMESTAMP we can also ignore as there is nothing we can do on our side.
        if ([operation isKindOfClass:[TLPushFileOperation class]]) {
            TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
            TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
            if (fileDescriptor) {
                [fileDescriptor setReceivedTimestamp:-1];
                [fileDescriptor setReadTimestamp:-1];
                [self updateWithDescriptor:fileDescriptor conversation:connection.conversation];
            }
            
        } else if ([operation isKindOfClass:[TLPushObjectOperation class]])  {
            TLPushObjectOperation *pushObjectOperation = (TLPushObjectOperation *)operation;
            TLObjectDescriptor *objectDescriptor = pushObjectOperation.objectDescriptor;
            if (objectDescriptor) {
                [objectDescriptor setReceivedTimestamp:-1];
                [objectDescriptor setReadTimestamp:-1];
                [self updateWithDescriptor:objectDescriptor conversation:connection.conversation];
            }
        }
    }
    
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)processOnErrorIQWithConnection:(nonnull TLConversationConnection *)connection onErrorIQ:(nonnull TLErrorIQ *)onErrorIQ {
    DDLogVerbose(@"%@ processOnErrorIQWithConnection: %@ onErrorIQ: %@", LOG_TAG, connection, onErrorIQ);
    
    TLConversationServiceOperation *operation = [self.scheduler getFirstActiveOperationWithConversation:connection.conversation];
    [self.scheduler finishOperation:operation connection:connection];
}

- (void)popWithDescriptor:(nonnull TLDescriptor *)descriptor connection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ popWithDescriptor: %@ connection: %@", LOG_TAG, descriptor, connection);

    [descriptor adjustCreatedAndSentTimestamps:connection.peerTimeCorrection];
    descriptor.receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    id<TLConversation> conversation = connection.conversation.mainConversation;
    TLConversationServiceProviderResult result = [self.serviceProvider insertOrUpdateDescriptorWithConversation:conversation descriptor:descriptor];
    
    // If the message was inserted, propagate it to upper layers through the onPopDescriptor callback.
    // Otherwise, we already know the message and we only need to acknowledge the sender.
    if (result == TLConversationServiceProviderResultStored) {
        connection.conversation.isActive = YES;

        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:descriptor];
                });
            }
        }
    }
}

- (void)updateWithDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull TLConversationImpl *)conversationImpl {
    DDLogVerbose(@"%@ updateWithDescriptor: %@ conversation: %@", LOG_TAG, descriptor, conversationImpl);

    [self.serviceProvider updateDescriptorTimestamps:descriptor];

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:descriptor updateType:TLConversationServiceUpdateTypeTimestamps];
            });
        }
    }
}

- (nullable NSString *)getPathWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nullable NSString*)extension {
    DDLogVerbose(@"%@ getPathWithDescriptor: %@", LOG_TAG, descriptor);
    
    NSString *path;
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    if (extension) {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld.%@", [descriptorId.twincodeOutboundId UUIDString], descriptorId.sequenceId, extension];
    } else {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld", [descriptorId.twincodeOutboundId UUIDString], descriptorId.sequenceId];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:path];
    
    if ([fileManager fileExistsAtPath:absolutePath]) {
        return path;
    }
    
    if ([fileManager createDirectoryAtPath:[absolutePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        if ([fileManager createFileAtPath:absolutePath contents:[[NSData alloc] init] attributes:nil]) {
            return path;
        }
    }
    return nil;
}

- (void)writeThumbnailWithDescriptorId:(nonnull TLDescriptorId *)descriptorId thumbnailData:(nonnull NSData *)thumbnailData append:(BOOL)append {
    DDLogVerbose(@"%@ writeThumbnailWithDescriptorId: %@ append: %d", LOG_TAG, descriptorId, append);
    
    NSString *cdir = [NSString stringWithFormat:@"Conversations/%@", [descriptorId.twincodeOutboundId UUIDString]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:cdir];
    
    if (![fileManager createDirectoryAtPath:absolutePath withIntermediateDirectories:YES attributes:nil error:nil]) {
        [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return;
    }
    
    // Save the thumbnail data in a specific file.
    NSString *path = [NSString stringWithFormat:@"%@/%lld", cdir, descriptorId.sequenceId];
    NSString *thumbPath = [TLTwinlife getAppGroupPath:fileManager path:[path stringByAppendingString:@"-thumbnail.jpg"]];

    if (!append) {
        if ([fileManager fileExistsAtPath:thumbPath]) {
            [fileManager removeItemAtPath:thumbPath error:nil];
        }
        
        if (![fileManager createFileAtPath:thumbPath contents:thumbnailData attributes:nil]) {
            [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
            return;
        }
        return;
    }

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:thumbPath];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:thumbnailData];
    [fileHandle closeFile];
}

- (nullable NSString *)saveThumbnailWithDescriptor:(nonnull TLFileDescriptor *)descriptor thumbnailData:(nullable NSData *)thumbnailData {
    DDLogVerbose(@"%@ saveThumbnailWithDescriptor: %@", LOG_TAG, descriptor);
    
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    NSString *cdir = [NSString stringWithFormat:@"Conversations/%@", [descriptorId.twincodeOutboundId UUIDString]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:cdir];
    
    if (![fileManager createDirectoryAtPath:absolutePath withIntermediateDirectories:YES attributes:nil error:nil]) {
        [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return nil;
    }

    NSString *path = [NSString stringWithFormat:@"%@/%lld", cdir, descriptorId.sequenceId];

    // Save the thumbnail data in a specific file.
    if (thumbnailData) {
        NSString *thumbPath = [TLTwinlife getAppGroupPath:fileManager path:[path stringByAppendingString:@"-thumbnail.jpg"]];

        if (![fileManager createFileAtPath:thumbPath contents:thumbnailData attributes:nil]) {
            [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
            return nil;
        }
    }

    NSString *extension = descriptor.extension;
    if (extension) {
        path = [NSString stringWithFormat:@"%@.%@", path, extension];
    }

    absolutePath = [TLTwinlife getAppGroupPath:fileManager path:path];
    if (![fileManager createFileAtPath:absolutePath contents:[[NSData alloc] init] attributes:nil]) {
        [self onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return nil;
    }
    
    return path;
}

- (BOOL)copyFileWithDescriptor:(nonnull TLFileDescriptor *)descriptor destination:(nonnull TLFileDescriptor *)destination {
    DDLogVerbose(@"%@ copyFileWithDescriptor: %@ destination: %@", LOG_TAG, descriptor, destination);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *sourcePath = [descriptor getPathWithFileManager:fileManager];
    NSString *destinationPath = [destination getPathWithFileManager:fileManager];
    if (![fileManager fileExistsAtPath:sourcePath]) {
        return NO;
    }
    
    NSString *destinationDir = [destinationPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:destinationDir] && ![fileManager createDirectoryAtPath:destinationDir withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }

    NSError *error;
    if (![fileManager copyItemAtPath:sourcePath toPath:destinationPath error:&error]) {
        return NO;
    }

    NSString *sourceThumbnail = [descriptor thumbnailPath];
    if (sourceThumbnail) {
        NSString *destinationThumbnail = [destination thumbnailPath];
        if (destinationThumbnail) {
            if (![fileManager copyItemAtPath:sourceThumbnail toPath:destinationThumbnail error:&error]) {
                [fileManager removeItemAtPath:destinationPath error:&error];
                return NO;
            }
        }
    }

    return YES;
}

- (NSString *)saveFileWithDescriptor:(TLDescriptor *)descriptor path:(NSString *)path toBeDeleted:(BOOL)toBeDeleted {
    DDLogVerbose(@"%@ saveFileWithDescriptor: %@ path: %@ toBeDeleted: %@", LOG_TAG, descriptor, path, toBeDeleted ? @"YES" : @"NO");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if  (![fileManager fileExistsAtPath:path]) {
        return nil;
    }
    
    NSString *extension = nil;
    // NSString *name = nil;
    // int64_t length = -1;
    extension = [path pathExtension];
    // name = [path lastPathComponent];
    // length = [[[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] longLongValue];
    
    NSString *targetPath = nil;
    targetPath = [self getPathWithDescriptor:descriptor extension:extension];
    if (targetPath) {
        NSString *toPath = [TLTwinlife getAppGroupPath:fileManager path:targetPath];
        NSError *error;
        [fileManager removeItemAtPath:toPath error:&error];
        if (![fileManager copyItemAtPath:path toPath:toPath error:&error]) {
            [fileManager removeItemAtPath:toPath error:&error];
            targetPath = nil;
        }
    }
    
    if (toBeDeleted) {
        [fileManager removeItemAtPath:path error:nil];
    }
    return targetPath;
}

- (TLFileDescriptor *)importFileWithConversation:(id <TLConversation>)conversation requestId:(int64_t)requestId sendTo:(nullable NSUUID*)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ importFileWithConversation: %@ path: %@ type: %u toBeDeleted: %@ copyAllowed: %d", LOG_TAG, conversation, path, type, toBeDeleted ? @"YES" : @"NO", copyAllowed);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if  (![fileManager fileExistsAtPath:path]) {
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeFileNotFound errorParameter:nil];
        return nil;
    }
    
    NSString *extension = nil;
    NSString *name = nil;
    int64_t length = -1;
    extension = [path pathExtension];
    name = [path lastPathComponent];
    length = [[[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] longLongValue];
    TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithId:0 twincodeOutboundId:conversation.twincodeOutboundId sequenceId:[self newSequenceId]];
    TLDescriptor *descriptor = [[TLDescriptor alloc] initWithDescriptorId:descriptorId conversationId:0 sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    NSString *toPath = nil;
    NSString *fileDescriptorPath = [self getPathWithDescriptor:descriptor extension:extension];
    if (fileDescriptorPath) {
        toPath = [TLTwinlife getAppGroupPath:fileManager path:fileDescriptorPath];
        NSError *error;
        [fileManager removeItemAtPath:toPath error:&error];
        BOOL result;
        if (toBeDeleted) {
            result = [fileManager moveItemAtPath:path toPath:toPath error:&error];
        } else {
            result = [fileManager copyItemAtPath:path toPath:toPath error:&error];
        }
        if (!result) {
            // Copy failed (file system full or another error), cleanup and cancel.
            [fileManager removeItemAtPath:toPath error:nil];
            descriptor = nil;
        }
    } else {
        descriptor = nil;
    }
    if (toBeDeleted) {
        [fileManager removeItemAtPath:path error:nil];
    }

    if (!descriptor || !toPath) {
        // Copy or move failed, report a storage error.
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeNoStorageSpace errorParameter:nil];
        return nil;
    }
    
    TLFileDescriptor *fileDescriptor = nil;
    switch (type) {
        case TLDescriptorTypeImageDescriptor: {
            NSURL *url = [NSURL fileURLWithPath:toPath];
            fileDescriptor = [[TLImageDescriptor alloc] initWithDescriptor:descriptor url:url extension:extension length:length copyAllowed:copyAllowed];

            break;
        }
            
        case TLDescriptorTypeAudioDescriptor: {
            NSURL *url = [NSURL fileURLWithPath:toPath];
            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
            CMTime time = asset.duration;
            int64_t duration = (int64_t)CMTimeGetSeconds(time);
            fileDescriptor = [[TLAudioDescriptor alloc] initWithDescriptor:descriptor extension:extension length:length end:length duration:duration copyAllowed:copyAllowed];
            break;
        }
            
        case TLDescriptorTypeVideoDescriptor: {
            NSURL *url = [NSURL fileURLWithPath:toPath];
            fileDescriptor = [[TLVideoDescriptor alloc] initWithDescriptor:descriptor url:url extension:extension length:length copyAllowed:copyAllowed];
            break;
        }
            
        case TLDescriptorTypeNamedFileDescriptor: {
            fileDescriptor = [[TLNamedFileDescriptor alloc] initWithDescriptor:descriptor extension:extension length:length end:length name:name copyAllowed:copyAllowed];
            break;
        }
            
        default:
            break;
    }

    // If an error occurred, erase the file saved by getPathWithDescriptor.
    if (!fileDescriptor) {
        [fileManager removeItemAtPath:toPath error:nil];
        [self onErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeFileNotSupported errorParameter:nil];
    } else {
        fileDescriptor.updatedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    }
    return fileDescriptor;
}

- (void)deleteFilesWithConversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ deleteFilesWithConversation: %@", LOG_TAG, conversation);
    DDLogInfo(@"%@ deleteFilesWithConversation: %@", LOG_TAG, conversation);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath;
    
    // Remove the files we have sent except for a group member conversation when the member is removed.
    if (![conversation isGroup] || [conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        absolutePath = [TLTwinlife getAppGroupPath:fileManager path:[NSString stringWithFormat:@"Conversations/%@",  [conversation.twincodeOutboundId UUIDString]]];
        [fileManager removeItemAtPath:absolutePath error:nil];
    }
    
    absolutePath = [TLTwinlife getAppGroupPath:fileManager path:[NSString stringWithFormat:@"Conversations/%@",  [conversation.peerTwincodeOutboundId UUIDString]]];
    [fileManager removeItemAtPath:absolutePath error:nil];
}

+ (BOOL)isSmallImageWithPath:(nonnull NSString *)path fileManager:(nonnull NSFileManager *)fileManager {
    DDLogVerbose(@"%@ isSmallImageWithPath: %@", LOG_TAG, path);

    if (![path hasSuffix:@".jpg"] && ![path hasSuffix:@".png"] && ![path hasSuffix:@".gif"]) {
        return NO;
    }

    int64_t length = [[[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] longLongValue];

    return length <= THUMBNAIL_MIN_LENGTH;
}

- (void)deleteFilesWithDescriptors:(nonnull NSSet<TLDescriptorId *> *)descriptorIds {
    DDLogInfo(@"%@ deleteFilesWithDescriptors: %@", LOG_TAG, descriptorIds);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSCharacterSet *dash = [NSCharacterSet characterSetWithCharactersInString:@"-"];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:@"Conversations"];

    NSMutableDictionary<NSUUID *, NSMutableSet<NSNumber *> *> *deleteMap = [[NSMutableDictionary alloc] init];
    for (TLDescriptorId *descriptorId in descriptorIds) {
        NSMutableSet<NSNumber *> *seqList = [deleteMap objectForKey:descriptorId.twincodeOutboundId];
        if (!seqList) {
            seqList = [[NSMutableSet alloc] init];
            [deleteMap setObject:seqList forKey:descriptorId.twincodeOutboundId];
        }
        [seqList addObject:[[NSNumber alloc] initWithLongLong:descriptorId.sequenceId]];
    }

    // Scan and erase the files matching our sequence ids (the extension is not known).
    for (NSUUID *twincodeOutboundId in deleteMap) {
        NSMutableSet<NSNumber*> *seqList = deleteMap[twincodeOutboundId];
        NSString *path = [absolutePath stringByAppendingPathComponent:[twincodeOutboundId UUIDString]];
        NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:path error:nil];
        if (files) {
            for (NSString *file in files) {
                NSString *fileName = [file stringByDeletingPathExtension];
                NSRange sep = [fileName rangeOfCharacterFromSet:dash options:NSBackwardsSearch];
                int64_t sequenceId;

                // We must take into account thumbnail files in the form <sequence>-thumbnail.<ext>.
                // The thumbnail file is kept when CLEAR_MEDIA is used, it is removed in other modes.
                if (sep.location == NSNotFound) {
                    sequenceId = [fileName longLongValue];
                } else {
                    sequenceId = [[fileName substringToIndex:sep.location] longLongValue];
                }

                if ([seqList containsObject:[[NSNumber alloc] initWithLongLong:sequenceId]]) {
                    NSString *toDeletePath = [NSString stringWithFormat:@"%@/%@", path, file];

                    DDLogInfo(@"%@ deleteUnreacheableFile: %@", LOG_TAG, toDeletePath);
                    [fileManager removeItemAtPath:toDeletePath error:nil];
                }
            }
        }
    }
}

- (void)deleteUnreacheableFilesWithConversation:(nonnull id <TLConversation>)conversation resetList:(nullable NSDictionary<NSUUID *, TLDescriptorId *> *)resetList clearMode:(TLConversationServiceClearMode)clearMode {
    DDLogInfo(@"%@ deleteUnreacheableFilesWithConversation: %@ clearMode: %d", LOG_TAG, conversation, clearMode);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSCharacterSet *dash = [NSCharacterSet characterSetWithCharactersInString:@"-"];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:@"Conversations"];

    for (NSUUID *twincodeOutboundId in resetList) {
        TLDescriptorId *descriptorId = resetList[twincodeOutboundId];
        if (descriptorId) {
            NSString *path = [absolutePath stringByAppendingPathComponent:[twincodeOutboundId UUIDString]];
            NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:path error:nil];
            if (files) {
                for (NSString *file in files) {
                    NSString *fileName = [file stringByDeletingPathExtension];
                    NSRange sep = [fileName rangeOfCharacterFromSet:dash options:NSBackwardsSearch];
                    int64_t sequenceId;

                    // We must take into account thumbnail files in the form <sequence>-thumbnail.<ext>.
                    // The thumbnail file is kept when CLEAR_MEDIA is used, it is removed in other modes.
                    if (sep.location == NSNotFound) {
                        sequenceId = [fileName longLongValue];
                    } else if (clearMode != TLConversationServiceClearMedia) {
                        sequenceId = [[fileName substringToIndex:sep.location] longLongValue];
                    } else {
                        sequenceId = LONG_MAX;
                    }

                    if (sequenceId <= descriptorId.sequenceId) {
                        NSString *toDeletePath = [NSString stringWithFormat:@"%@/%@", path, file];

                        // In CLEAR_MEDIA mode, we don't erase the file if it is smaller than 100K.
                        if (clearMode != TLConversationServiceClearMedia || ![TLConversationService isSmallImageWithPath:toDeletePath fileManager:fileManager]) {
                            DDLogInfo(@"%@ deleteUnreacheableFile: %@", LOG_TAG, toDeletePath);
                            [fileManager removeItemAtPath:toDeletePath error:nil];
                        }
                    }
                }
            }
        }
    }

}

- (void)deleteAllFiles {
    DDLogVerbose(@"%@ deleteAllFiles", LOG_TAG);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = [TLTwinlife getAppGroupPath:fileManager path:@"Conversations"];
    [[NSFileManager defaultManager] removeItemAtPath:absolutePath error:nil];
}

- (MPMediaItem *)getMediaItemForURL:(NSURL *)url {
    DDLogVerbose(@"%@ getMediaItemForURL: %@", LOG_TAG, url);
    
    NSString *queryString = [url query];
    if (!queryString) {
        return nil;
    }
    NSArray *components = [queryString componentsSeparatedByString:@"="];
    if (components.count < 2) {
        return nil;
    }
    id trackId = [components objectAtIndex:1];
    MPMediaQuery *query = [[MPMediaQuery alloc] init];
    [query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:trackId forProperty:MPMediaItemPropertyPersistentID]];
    NSArray *items = [query items];
    if (items.count < 1) {
        return nil;
    }
    return [items objectAtIndex:0];
}

@end
