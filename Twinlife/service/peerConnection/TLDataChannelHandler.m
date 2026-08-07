/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>
#include <stdatomic.h>

#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLSerializerFactoryImpl.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLDataChannelHandler.h"
#import "TLPeerConnectionServiceImpl.h"
#import "TLPeerCallServiceImpl.h"
#import "TLSessionUpdateIQ.h"
#import "TLTransportInfoIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLDataChannelHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLDataChannelHandler"

@interface TLDataChannelHandler ()

@property (nonatomic, readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLBinaryPacketListener> *binaryPacketListeners;

@end

//
// Implementation: TLDataChannelHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLDataChannelHandler"

@implementation TLDataChannelHandler

+ (BOOL)processSdpPacketWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService key:(nonnull TLSerializerKey *)key peerConnectionId:(nonnull NSUUID *)peerConnectionId binaryDecoder:(nonnull TLBinaryDecoder*)binaryDecoder {
    
    if ([[TLPeerCallService IQ_SESSION_UPDATE_SERIALIZER].schemaId isEqual:key.schemaId]) {
        TLSessionUpdateIQ *iq = (TLSessionUpdateIQ *)[[TLPeerCallService IQ_SESSION_UPDATE_SERIALIZER] deserializeWithSerializerFactory:peerConnectionService.twinlife.serializerFactory decoder:binaryDecoder];
        [peerConnectionService incrementStatWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];

        [TLDataChannelHandler onSessionUpdateWithIQ:iq peerConnectionService:peerConnectionService];
        return YES;

    } else if ([[TLPeerCallService IQ_TRANSPORT_INFO_SERIALIZER].schemaId isEqual:key.schemaId]) {
        TLTransportInfoIQ *iq = (TLTransportInfoIQ *)[[TLPeerCallService IQ_TRANSPORT_INFO_SERIALIZER] deserializeWithSerializerFactory:peerConnectionService.twinlife.serializerFactory decoder:binaryDecoder];
        [peerConnectionService incrementStatWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];

        [TLDataChannelHandler onTransportInfoWithIQ:iq peerConnectionService:peerConnectionService];
        return YES;

    } else if ([[TLPeerCallService IQ_ON_TRANSPORT_INFO_SERIALIZER].schemaId isEqual:key.schemaId]) {
        TLBinaryErrorPacketIQ *iq = (TLBinaryErrorPacketIQ *)[[TLPeerCallService IQ_ON_TRANSPORT_INFO_SERIALIZER] deserializeWithSerializerFactory:peerConnectionService.twinlife.serializerFactory decoder:binaryDecoder];
        [peerConnectionService incrementStatWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];

        [TLDataChannelHandler onAckSDPWithIQ:iq peerConnectionService:peerConnectionService peerConnectionId:peerConnectionId];
        return YES;

    } else if ([[TLPeerCallService IQ_ON_SESSION_UPDATE_SERIALIZER].schemaId isEqual:key.schemaId]) {
        TLTransportInfoIQ *iq = (TLTransportInfoIQ *)[[TLPeerCallService IQ_ON_TRANSPORT_INFO_SERIALIZER] deserializeWithSerializerFactory:peerConnectionService.twinlife.serializerFactory decoder:binaryDecoder];
        [peerConnectionService incrementStatWithPeerConnectionId:peerConnectionId statType:TLPeerConnectionServiceStatTypeIqReceiveSetCount];

        [TLDataChannelHandler onAckSDPWithIQ:iq peerConnectionService:peerConnectionService peerConnectionId:peerConnectionId];
        return YES;
    } else {
        return NO;
    }
}

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService {
    DDLogVerbose(@"%@ initWithPeerConnectionService", LOG_TAG);
    
    self = [super init];
    if (self) {
        _peerConnectionService = peerConnectionService;
        _serializerFactory = peerConnectionService.twinlife.serializerFactory;
        _binaryPacketListeners = [[NSMutableDictionary alloc] init];
        
        // Register the binary IQ handlers for the responses.
        __weak TLDataChannelHandler *handler = self;
        [self addPacketListener:[TLPeerCallService IQ_SESSION_UPDATE_SERIALIZER] listener:^(TLBinaryPacketIQ * iq) {
            [TLDataChannelHandler onSessionUpdateWithIQ:iq peerConnectionService:peerConnectionService];
        }];
        [self addPacketListener:[TLPeerCallService IQ_TRANSPORT_INFO_SERIALIZER] listener:^(TLBinaryPacketIQ * iq) {
            [TLDataChannelHandler onTransportInfoWithIQ:iq peerConnectionService:peerConnectionService];
        }];
        [self addPacketListener:[TLPeerCallService IQ_ON_SESSION_UPDATE_SERIALIZER] listener:^(TLBinaryPacketIQ * iq) {
            [TLDataChannelHandler onAckSDPWithIQ:iq peerConnectionService:peerConnectionService peerConnectionId:handler.peerConnectionId];
        }];
        [self addPacketListener:[TLPeerCallService IQ_ON_TRANSPORT_INFO_SERIALIZER] listener:^(TLBinaryPacketIQ * iq) {
            [TLDataChannelHandler onAckSDPWithIQ:iq peerConnectionService:peerConnectionService peerConnectionId:handler.peerConnectionId];
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
    
    @throw [NSException exceptionWithName:@"configurationWithPeerConnectionId not implemented" reason:@"method must be overriden" userInfo:nil];
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

+ (void)onSessionUpdateWithIQ:(nonnull TLBinaryPacketIQ *)iq peerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService {
    DDLogVerbose(@"%@ onSessionUpdateWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSessionUpdateIQ class]]) {
        return;
    }
    TLSessionUpdateIQ *sessionUpdateIQ = (TLSessionUpdateIQ *)iq;

    // Send the ACK immediately.
    TLBinaryErrorPacketIQ *ackIq = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:[TLPeerCallService IQ_ON_SESSION_UPDATE_SERIALIZER] requestId:iq.requestId errorCode:TLBaseServiceErrorCodeSuccess];
    [peerConnectionService sendPacketWithPeerConnectionId:sessionUpdateIQ.sessionId statType:TLPeerConnectionServiceStatTypeIqResultSdpSessionUpdate iq:ackIq];
    
    RTCSdpType type = [sessionUpdateIQ type];
    TLSdp *sdp = [sessionUpdateIQ makeSdp];
    int64_t sequenceId = [sessionUpdateIQ sequenceId];
    
    [peerConnectionService onSessionUpdateWithSessionId:sessionUpdateIQ.sessionId updateType:type sdp:sdp sequenceId:sequenceId];
}

+ (void)onTransportInfoWithIQ:(nonnull TLBinaryPacketIQ *)iq peerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService {
    DDLogVerbose(@"%@ onTransportInfoWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLTransportInfoIQ class]]) {
        return;
    }
    
    // Send the ACK immediately.
    TLTransportInfoIQ *transportInfoIQ = (TLTransportInfoIQ *)iq;
    TLBinaryErrorPacketIQ *ackIq = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:[TLPeerCallService IQ_ON_TRANSPORT_INFO_SERIALIZER] requestId:iq.requestId errorCode:TLBaseServiceErrorCodeSuccess];
    [peerConnectionService sendPacketWithPeerConnectionId:transportInfoIQ.sessionId statType:TLPeerConnectionServiceStatTypeIqResultSdpTransportInfo iq:ackIq];
    
    TLSdp *sdp = [transportInfoIQ makeSdp];
    [peerConnectionService onTransportInfoWithSessionId:transportInfoIQ.sessionId sdp:sdp];
}

+ (void)onAckSDPWithIQ:(nonnull TLBinaryPacketIQ *)iq peerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService peerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ onAckSDPWithIQ: %@", LOG_TAG, iq);

    [peerConnectionService ackPacketWithPeerConnectionId:peerConnectionId requestId:iq.requestId];
}

@end
