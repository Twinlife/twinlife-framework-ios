/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLPeerCallServiceImpl.h"
#import "TLSessionInitiateIQ.h"
#import "TLSessionAcceptIQ.h"
#import "TLSessionUpdateIQ.h"
#import "TLSessionPingIQ.h"
#import "TLTransportInfoIQ.h"
#import "TLCreateCallRoomIQ.h"
#import "TLOnCreateCallRoomIQ.h"
#import "TLInviteCallRoomIQ.h"
#import "TLJoinCallRoomIQ.h"
#import "TLOnJoinCallRoomIQ.h"
#import "TLMemberNotificationIQ.h"
#import "TLLeaveCallRoomIQ.h"
#import "TLSessionTerminateIQ.h"
#import "TLDeviceRingingIQ.h"
#import "TLMemberSessionInfo.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLSdp.h"

#define CREATE_CALL_ROOM_SCHEMA_ID       @"e53c8953-6345-4e77-bf4b-c1dc227d5d2f"
#define ON_CREATE_CALL_ROOM_SCHEMA_ID    @"9e53e24a-acf3-4819-8539-2af37272254f"
#define INVITE_CALL_ROOM_SCHEMA_ID       @"8974ff91-a6c6-42d7-b2a2-fc11041892bd"
#define ON_INVITE_CALL_ROOM_SCHEMA_ID    @"274dd1fb-a983-4709-91b0-825152742e1e"
#define JOIN_CALL_ROOM_SCHEMA_ID         @"f34ce0b8-8b1c-4384-b7a3-19fddcfd2789"
#define ON_JOIN_CALL_ROOM_SCHEMA_ID      @"fd30c970-a16c-4346-936d-d541aa239cb8"
#define MEMBER_NOTIFICATION_SCHEMA_ID    @"f7460e42-387c-41fe-97c3-18a5f2a97052"
#define LEAVE_CALL_ROOM_SCHEMA_ID        @"ffc5b5d4-a5e7-471e-aef3-97fadfdbda94"
#define ON_LEAVE_CALL_ROOM_SCHEMA_ID     @"ae2211fe-60ed-4518-ae90-e9dc5393f0d9"
#define DESTROY_CALL_ROOM_SCHEMA_ID      @"f4e195c7-3f84-4e05-a268-b4e3a956a787"
#define ON_DESTROY_CALL_ROOM_SCHEMA_ID   @"fac9a8de-c608-4d8f-b0e0-6c390584c41a"

#define SESSION_INITIATE_SCHEMA_ID       @"0ac5f97d-0fa1-4e18-bd99-c13297086752"
#define SESSION_ACCEPT_SCHEMA_ID         @"fd545960-d9ac-4e3e-bddf-76f381f163a5"
#define SESSION_UPDATE_SCHEMA_ID         @"44f0c7d0-8d03-453d-8587-714ef92087ae"
#define TRANSPORT_INFO_SCHEMA_ID         @"fdf1bba1-0c16-4b12-a59c-0f70cf4da1d9"
#define SESSION_PING_SCHEMA_ID           @"f2cb4a52-7928-42cb-8439-248388b9a4c7"
#define SESSION_TERMINATE_SCHEMA_ID      @"342d4d82-d91f-437b-bcf2-a2051bd94ac1"
#define DEVICE_RINGING_SCHEMA_ID         @"acd63138-bec7-402d-86d3-b82707d8b40c"

#define ON_SESSION_INITIATE_SCHEMA_ID    @"34469234-0f9b-48ea-88b1-f353808b6492"
#define ON_SESSION_ACCEPT_SCHEMA_ID      @"39b4838a-857c-4d03-9a63-c226fab2cd01"
#define ON_SESSION_UPDATE_SCHEMA_ID      @"1bdb2a25-33a7-4caf-af96-b90af26a478f"
#define ON_TRANSPORT_INFO_SCHEMA_ID      @"edf481e9-d584-4366-8c32-997cb33cf2c1"
#define ON_SESSION_PING_SCHEMA_ID        @"6825a073-b8f0-469e-b283-16fb4d3d0f80"
#define ON_SESSION_TERMINATE_SCHEMA_ID   @"d9585220-4c8f-4a24-8e71-d7f81a4abe37"

#define DEFAULT_EXPIRATION_TIMEOUT (30 * 1000L)

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define PEER_CALL_SERVICE_VERSION @"1.4.1"

static TLBinaryPacketIQSerializer *IQ_CREATE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_INVITE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_INVITE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_JOIN_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_JOIN_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_MEMBER_NOTIFICATION_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_LEAVE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_LEAVE_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DESTROY_CALL_ROOM_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DESTROY_CALL_ROOM_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_SESSION_INITIATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SESSION_ACCEPT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SESSION_UPDATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_TRANSPORT_INFO_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SESSION_PING_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_SESSION_TERMINATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DEVICE_RINGING_SERIALIZER = nil;

static TLBinaryPacketIQSerializer *IQ_ON_SESSION_INITIATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SESSION_ACCEPT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SESSION_UPDATE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_TRANSPORT_INFO_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SESSION_PING_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_SESSION_TERMINATE_SERIALIZER = nil;

//
// Implementation: TLPeerCallMemberInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerCallMemberInfo"

@implementation TLPeerCallMemberInfo : NSObject

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId {
    DDLogVerbose(@"%@ initWithMemberId: %@", LOG_TAG, memberId);

    self = [super init];
    if (self) {
        _memberId = memberId;
        _p2pSessionId = nil;
        _status = TLMemberStatusNewNeedSession;
    }
    return self;
}

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId p2pSessionId:(nonnull NSUUID *)p2pSessionId {
    DDLogVerbose(@"%@ initWithMemberId: %@ p2pSessionId: %@", LOG_TAG, memberId, p2pSessionId);

    self = [super init];
    if (self) {
        _memberId = memberId;
        _p2pSessionId = p2pSessionId;
        _status = TLMemberStatusNew;
    }
    return self;
}

#pragma mark - NSObject

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"TLPeerCallMemberInfo: %@ sessionId: %@ status: %u", self.memberId, self.p2pSessionId, self.status];
    return string;
}

@end

//
// Implementation: TLPeerCallServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerCallServiceConfiguration"

@implementation TLPeerCallServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdPeerCallService version:[TLPeerCallService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLPendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLPendingRequest"

@implementation TLPendingRequest

@end

//
// Implementation: TLCallRoomPendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLCallRoomPendingRequest"

@implementation TLCallRoomPendingRequest

-(nonnull instancetype)initWithCallRoomId:(nonnull NSUUID *)callRoomId {
    
    self = [super init];
    if (self) {
        _callRoomId = callRoomId;
    }
    return self;
}

@end

//
// Implementation: TLPeerSessionInfo
//

@implementation TLPeerSessionInfo

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId peerId:(nullable NSString *)peerId {
    
    self = [super init];
    if (self) {
        _p2pSessionId = sessionId;
        _peerId = peerId;
    }
    return self;
}

@end

//
// Implementation: TLSessionPendingRequest ()
//

#undef LOG_TAG
#define LOG_TAG @"TLCallRoomPendingRequest"

@implementation TLSessionPendingRequest

-(nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    
    self = [super init];
    if (self) {
        _sessionId = sessionId;
        _consumer = block;
    }
    return self;
}

@end

//
// Implementation: TLPeerCallService
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerCallService"

@implementation TLPeerCallService

+ (void)initialize {
    
    IQ_CREATE_CALL_ROOM_SERIALIZER = [[TLCreateCallRoomIQSerializer alloc] initWithSchema:CREATE_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    IQ_INVITE_CALL_ROOM_SERIALIZER = [[TLInviteCallRoomIQSerializer alloc] initWithSchema:INVITE_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    IQ_JOIN_CALL_ROOM_SERIALIZER = [[TLJoinCallRoomIQSerializer alloc] initWithSchema:JOIN_CALL_ROOM_SCHEMA_ID schemaVersion:3];
    IQ_MEMBER_NOTIFICATION_SERIALIZER = [[TLMemberNotificationIQSerializer alloc] initWithSchema:MEMBER_NOTIFICATION_SCHEMA_ID schemaVersion:1];
    IQ_LEAVE_CALL_ROOM_SERIALIZER = [[TLLeaveCallRoomIQSerializer alloc] initWithSchema:LEAVE_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    
    IQ_ON_CREATE_CALL_ROOM_SERIALIZER = [[TLOnCreateCallRoomIQSerializer alloc] initWithSchema:ON_CREATE_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    IQ_ON_INVITE_CALL_ROOM_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_INVITE_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    IQ_ON_JOIN_CALL_ROOM_SERIALIZER = [[TLOnJoinCallRoomIQSerializer alloc] initWithSchema:ON_JOIN_CALL_ROOM_SCHEMA_ID schemaVersion:1];
    IQ_ON_LEAVE_CALL_ROOM_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_LEAVE_CALL_ROOM_SCHEMA_ID schemaVersion:1];

    IQ_SESSION_INITIATE_SERIALIZER = [[TLSessionInitiateIQSerializer alloc] initWithSchema:SESSION_INITIATE_SCHEMA_ID schemaVersion:1];
    IQ_SESSION_ACCEPT_SERIALIZER = [[TLSessionAcceptIQSerializer alloc] initWithSchema:SESSION_ACCEPT_SCHEMA_ID schemaVersion:1];
    IQ_SESSION_UPDATE_SERIALIZER = [[TLSessionUpdateIQSerializer alloc] initWithSchema:SESSION_UPDATE_SCHEMA_ID schemaVersion:1];
    IQ_TRANSPORT_INFO_SERIALIZER = [[TLTransportInfoIQSerializer alloc] initWithSchema:TRANSPORT_INFO_SCHEMA_ID schemaVersion:1];
    IQ_SESSION_PING_SERIALIZER = [[TLSessionPingIQSerializer alloc] initWithSchema:SESSION_PING_SCHEMA_ID schemaVersion:1];
    IQ_SESSION_TERMINATE_SERIALIZER = [[TLSessionTerminateIQSerializer alloc] initWithSchema:SESSION_TERMINATE_SCHEMA_ID schemaVersion:1];
    IQ_DEVICE_RINGING_SERIALIZER = [[TLDeviceRingingIQSerializer alloc] initWithSchema:DEVICE_RINGING_SCHEMA_ID schemaVersion:1];

    IQ_ON_SESSION_INITIATE_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_SESSION_INITIATE_SCHEMA_ID schemaVersion:1];
    IQ_ON_SESSION_ACCEPT_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_SESSION_ACCEPT_SCHEMA_ID schemaVersion:1];
    IQ_ON_SESSION_UPDATE_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_SESSION_UPDATE_SCHEMA_ID schemaVersion:1];
    IQ_ON_TRANSPORT_INFO_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_TRANSPORT_INFO_SCHEMA_ID schemaVersion:1];
    IQ_ON_SESSION_PING_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_SESSION_PING_SCHEMA_ID schemaVersion:1];
    IQ_ON_SESSION_TERMINATE_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_SESSION_TERMINATE_SCHEMA_ID schemaVersion:1];

}

+ (nonnull NSString *)VERSION {
    
    return PEER_CALL_SERVICE_VERSION;
}

+ (TLOffer *)createOfferWithOffer:(int)offer version:(nonnull TLVersion *)version {
    
    BOOL data = (offer & OFFER_DATA) != 0;
    BOOL audio = (offer & OFFER_AUDIO) != 0;
    BOOL video = (offer & OFFER_VIDEO) != 0;
    BOOL videoBell = (offer & OFFER_VIDEO_BELL) != 0;
    BOOL group = (offer & OFFER_GROUP_CALL) != 0;
    BOOL transfer = (offer & OFFER_TRANSFER) != 0;
    
    return [[TLOffer alloc] initWithAudio:audio video:video videoBell:videoBell data:data group:group transfer:transfer version:version];
}

+ (TLOfferToReceive *)createOfferToReceiveWithOffer:(int)offer {
    
    BOOL data = (offer & OFFER_DATA) != 0;
    BOOL audio = (offer & OFFER_AUDIO) != 0;
    BOOL video = (offer & OFFER_VIDEO) != 0;
    
    return [[TLOfferToReceive alloc] initWithAudio:audio video:video data:data];
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    _pendingRequests = [[NSMutableDictionary alloc] init];
    _serializerFactory = self.twinlife.serializerFactory;
    
    // Register the binary IQ handlers for the responses.
    [twinlife addPacketListener:IQ_ON_CREATE_CALL_ROOM_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onCreateCallRoomWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_INVITE_CALL_ROOM_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_JOIN_CALL_ROOM_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onJoinCallRoomWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_LEAVE_CALL_ROOM_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onLeaveCallRoomWithIQ:iq];
    }];

    // Register binary IQ handlers for server notifications.
    [twinlife addPacketListener:IQ_INVITE_CALL_ROOM_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onInviteCallRoomWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_MEMBER_NOTIFICATION_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onMemberNotificationWithIQ:iq];
    }];

    // Signaling IQ (Note: we never receive a session-ping).
    [twinlife addPacketListener:IQ_SESSION_INITIATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onSessionInitiateWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_SESSION_ACCEPT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onSessionAcceptWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_SESSION_UPDATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onSessionUpdateWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_TRANSPORT_INFO_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onTransportInfoWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_SESSION_TERMINATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onSessionTerminateWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_DEVICE_RINGING_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onDeviceRingingWithIQ:iq];
    }];

    [twinlife addPacketListener:IQ_ON_SESSION_INITIATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_SESSION_ACCEPT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_SESSION_UPDATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_TRANSPORT_INFO_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_SESSION_PING_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_SESSION_TERMINATE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onAckPacketWithIQ:iq];
    }];

    return self;
}

#pragma mark - BaseServiceImpl

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    if ([delegate conformsToProtocol:@protocol(TLPeerCallServiceDelegate)]) {
        [super addDelegate:delegate];
    }
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLPeerCallServiceConfiguration* peerCallServiceConfiguration = [[TLPeerCallServiceConfiguration alloc] init];
    TLPeerCallServiceConfiguration* serviceConfiguration = (TLPeerCallServiceConfiguration *) baseServiceConfiguration;
    peerCallServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = peerCallServiceConfiguration;
    self.serviceOn = peerCallServiceConfiguration.isServiceOn;
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
}

#pragma mark - TLPeerCallService

/// Create a call room with the given twincode identification.  The user must be owner of that twincode.
/// A list of member twincode with their optional P2P session id can be passed and those members are invited
/// to join the room.  Members that are invited will receive a call to their `onInviteCallRoom` callback.
///
/// @param requestId the request identifier.
/// @param twincodeOutboundId the owner twincode.
/// @param members the list of members to invite.
- (void)createCallRoomWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId members:(nonnull NSDictionary<NSString *, NSUUID *> *)members {
    DDLogVerbose(@"%@ createCallRoomWithRequestId: %lld twincodeOutboundId: %@ members: %@", LOG_TAG, requestId, twincodeOutboundId, members);

    TLPendingRequest *pendingRequest = [[TLPendingRequest alloc] init];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }

    NSMutableArray<TLMemberSessionInfo *> *list = [[NSMutableArray alloc] initWithCapacity:members.count];
    for (NSString *peerMemberId in members) {
        [list addObject:[[TLMemberSessionInfo alloc] initWithMemberId:peerMemberId sessionId:members[peerMemberId]]];
    }
    
    TLCreateCallRoomIQ *createCallRoomIQ = [[TLCreateCallRoomIQ alloc] initWithSerializer:IQ_CREATE_CALL_ROOM_SERIALIZER requestId:requestId ownerId:twincodeOutboundId memberId:twincodeOutboundId mode:0 members:list sfuURI:nil];
    [self sendBinaryIQ:createCallRoomIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Invite a new member in the call room.  Similar to `createCallRoom` to invite another member in the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room.
/// @param twincodeOutboundId the member to invite.
/// @param p2pSessionId the optional P2P session with that member.
- (void)inviteCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId p2pSessionId:(nonnull NSUUID *)p2pSessionId {
    DDLogVerbose(@"%@ inviteCallRoomWithRequestId: %lld callRoomId: %@ twincodeOutboundId: %@ p2pSessionId: %@", LOG_TAG, requestId, callRoomId, twincodeOutboundId, p2pSessionId);

    TLCallRoomPendingRequest *pendingRequest = [[TLCallRoomPendingRequest alloc] initWithCallRoomId:callRoomId];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }

    TLInviteCallRoomIQ *inviteCallRoomIQ = [[TLInviteCallRoomIQ alloc] initWithSerializer:IQ_INVITE_CALL_ROOM_SERIALIZER requestId:requestId callRoomId:callRoomId twincodeId:twincodeOutboundId p2pSessionId:p2pSessionId mode:0 maxMemberCount:0];
    [self sendBinaryIQ:inviteCallRoomIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];

}

/// Join the call room after having received an invitation through `onInviteCallRoom`.
/// The `twincodeOut` must be owned by the current user and represents the current user in the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room to join.
/// @param twincodeInboundId the member twincode.
/// @param p2pSessionIds the optional P2P sessions that we have with the call room members.
- (void)joinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionIds:(nonnull NSArray<TLPeerSessionInfo *> *)p2pSessionIds {
    DDLogVerbose(@"%@ joinCallRoomWithRequestId: %lld twincodeInboundId: %@ callRoomId: %@ p2pSessionIds: %@", LOG_TAG, requestId, callRoomId, twincodeInboundId, p2pSessionIds);

    TLCallRoomPendingRequest *pendingRequest = [[TLCallRoomPendingRequest alloc] initWithCallRoomId:callRoomId];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }

    TLJoinCallRoomIQ *joinCallRoomIQ = [[TLJoinCallRoomIQ alloc] initWithSerializer:IQ_JOIN_CALL_ROOM_SERIALIZER requestId:requestId callRoomId:callRoomId twincodeId:twincodeInboundId p2pSessionIds:p2pSessionIds];
    [self sendBinaryIQ:joinCallRoomIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Leave the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room to leave.
/// @param memberId the member id to remove.
- (void)leaveCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId {
    DDLogVerbose(@"%@ leaveCallRoomWithRequestId: %lld callRoomId: %@ memberId: %@", LOG_TAG, requestId, callRoomId, memberId);

    TLCallRoomPendingRequest *pendingRequest = [[TLCallRoomPendingRequest alloc] initWithCallRoomId:callRoomId];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }

    TLLeaveCallRoomIQ *leaveCallRoomIQ = [[TLLeaveCallRoomIQ alloc] initWithSerializer:IQ_LEAVE_CALL_ROOM_SERIALIZER requestId:requestId callRoomId:callRoomId memberId:memberId];
    [self sendBinaryIQ:leaveCallRoomIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void) transferDone {
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onTransferDone)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onTransferDone];
            });
        }
    }
}

/// Send the session-initiate to start a P2P connection with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param notificationContent information for the push notification.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionInitiateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate notificationContent:(nonnull TLNotificationContent *)notificationContent withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionInitiateWithSessionId: %@ to: %@ sdp: %@ offer: %@ offerToReceive: %@ maxReceivedFrameSize: %d maxReceivedFrameRate: %d", LOG_TAG, sessionId, to, sdp, offer, offerToReceive, maxReceivedFrameSize, maxReceivedFrameRate);

    int64_t expirationDeadline = [[NSDate date] timeIntervalSince1970] * 1000 + DEFAULT_EXPIRATION_TIMEOUT;
    int64_t requestId = [TLTwinlife newRequestId];
    NSString *fullJid = [self.twinlife getFullJid];
    int offerValue = (offer.audio ? OFFER_AUDIO : 0);
    if (offer.video) {
        offerValue |= OFFER_VIDEO;
    }
    if (offer.data) {
        offerValue |= OFFER_DATA;
    }
    if (offer.videoBell) {
        offerValue |= OFFER_VIDEO_BELL;
    }
    if (offer.group) {
        offerValue |= OFFER_GROUP_CALL;
    }
    if (offer.transfer) {
        offerValue |= OFFER_TRANSFER;
    }
    if ([sdp isCompressed]) {
        offerValue |= OFFER_COMPRESSED;
    }
    if ([sdp isEncrypted]) {
        offerValue |= ([sdp getKeyIndex] << OFFER_ENCRYPT_SHIFT) & OFFER_ENCRYPT_MASK;
    }
    int offerToReceiveValue = (offerToReceive.audio ? OFFER_AUDIO : 0);
    if (offerToReceive.data) {
        offerToReceiveValue |= OFFER_DATA;
    }
    if (offerToReceive.video) {
        offerToReceiveValue |= OFFER_VIDEO;
    }

    int priority = [notificationContent priority] == TLPeerConnectionServiceNotificationPriorityHigh ? 10 : 0;
    TLSessionInitiateIQ *sessionInitiateIQ = [[TLSessionInitiateIQ alloc] initWithSerializer:IQ_SESSION_INITIATE_SERIALIZER requestId:requestId from:fullJid to:to sessionId:sessionId majorVersion:PEER_CONNECTION_MAJOR_VERSION minorVersion:PEER_CONNECTION_MINOR_VERSION offer:offerValue offerToReceive:offerToReceiveValue priority:priority expirationDeadline:expirationDeadline frameSize:maxReceivedFrameSize frameRate:maxReceivedFrameRate estimatedDataSize:0 operationCount:0 sdp:[sdp data]];
    
    TLSessionPendingRequest *pendingRequest = [[TLSessionPendingRequest alloc] initWithSessionId:sessionId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:sessionInitiateIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send the session-accept to accept an incoming P2P connection with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionAcceptWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionAcceptWithSessionId: %@ to: %@ sdp: %@ offer: %@ offerToReceive: %@ maxReceivedFrameSize: %d maxReceivedFrameRate: %d", LOG_TAG, sessionId, to, sdp, offer, offerToReceive, maxReceivedFrameSize, maxReceivedFrameRate);

    int64_t expirationDeadline = [[NSDate date] timeIntervalSince1970] * 1000 + DEFAULT_EXPIRATION_TIMEOUT;
    int64_t requestId = [TLTwinlife newRequestId];
    NSString *fullJid = [self.twinlife getFullJid];
    int offerValue = (offer.audio ? OFFER_AUDIO : 0);
    if (offer.video) {
        offerValue |= OFFER_VIDEO;
    }
    if (offer.data) {
        offerValue |= OFFER_DATA;
    }
    if (offer.videoBell) {
        offerValue |= OFFER_VIDEO_BELL;
    }
    if (offer.group) {
        offerValue |= OFFER_GROUP_CALL;
    }
    if (offer.transfer) {
        offerValue |= OFFER_TRANSFER;
    }
    if ([sdp isCompressed]) {
        offerValue |= OFFER_COMPRESSED;
    }
    int offerToReceiveValue = (offerToReceive.audio ? OFFER_AUDIO : 0);
    if (offerToReceive.data) {
        offerToReceiveValue |= OFFER_DATA;
    }
    if (offerToReceive.video) {
        offerToReceiveValue |= OFFER_VIDEO;
    }
    if ([sdp isEncrypted]) {
        offerValue |= ([sdp getKeyIndex] << OFFER_ENCRYPT_SHIFT) & OFFER_ENCRYPT_MASK;
    }
    TLSessionAcceptIQ *sessionAcceptIQ = [[TLSessionAcceptIQ alloc] initWithSerializer:IQ_SESSION_ACCEPT_SERIALIZER requestId:requestId from:fullJid to:to sessionId:sessionId majorVersion:PEER_CONNECTION_MAJOR_VERSION minorVersion:PEER_CONNECTION_MINOR_VERSION offer:offerValue offerToReceive:offerToReceiveValue priority:0 expirationDeadline:expirationDeadline frameSize:maxReceivedFrameSize frameRate:maxReceivedFrameRate estimatedDataSize:0 operationCount:0 sdp:[sdp data]];
    
    TLSessionPendingRequest *pendingRequest = [[TLSessionPendingRequest alloc] initWithSessionId:sessionId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:sessionAcceptIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send the session-update to ask for a renegotiation with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the sdp to send.
/// @param type the update type to indicate whether this is an offer or answer.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionUpdateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to type:(RTCSdpType)type sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionUpdateWithSessionId: %@ to: %@ sdp: %@", LOG_TAG, sessionId, to, sdp);

    int64_t expirationDeadline = [[NSDate date] timeIntervalSince1970] * 1000 + DEFAULT_EXPIRATION_TIMEOUT;
    int64_t requestId = [TLTwinlife newRequestId];
    int mode = (type == RTCSdpTypeAnswer) ? OFFER_ANSWER : 0;
    if ([sdp isCompressed]) {
        mode |= OFFER_COMPRESSED;
    }
    if ([sdp isEncrypted]) {
        mode |= ([sdp getKeyIndex] << OFFER_ENCRYPT_SHIFT) & OFFER_ENCRYPT_MASK;
    }
    TLSessionUpdateIQ *sessionUpdateIQ = [[TLSessionUpdateIQ alloc] initWithSerializer:IQ_SESSION_UPDATE_SERIALIZER requestId:requestId to:to sessionId:sessionId expirationDeadline:expirationDeadline updateType:mode sdp:[sdp data]];
    
    TLSessionPendingRequest *pendingRequest = [[TLSessionPendingRequest alloc] initWithSessionId:sessionId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:sessionUpdateIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send the transport info for the P2P session to the peer.
///
/// @param requestId the request id
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP with the list of candidates.
/// @param block the completion handler executed when the server sends us its response.
- (void)transportInfoWithRequestId:(int64_t)requestId sessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ transportInfoWithSessionId: %@ to: %@ sdp: %@", LOG_TAG, sessionId, to, sdp);

    // The SDP can be empty if all candidates are already sent in a previous SDP transport info.
    NSNumber *reqId = [NSNumber numberWithLongLong:requestId];
    NSData *data = [sdp data];
    if (data.length == 0) {
        block(TLBaseServiceErrorCodeSuccess, reqId);
        return;
    }

    int64_t expirationDeadline = [[NSDate date] timeIntervalSince1970] * 1000 + DEFAULT_EXPIRATION_TIMEOUT;
    int mode = [sdp isCompressed] ? OFFER_COMPRESSED : 0;
    if ([sdp isEncrypted]) {
        mode |= ([sdp getKeyIndex] << OFFER_ENCRYPT_SHIFT) & OFFER_ENCRYPT_MASK;
    }
    TLTransportInfoIQ *transportInfoIQ = [[TLTransportInfoIQ alloc] initWithSerializer:IQ_TRANSPORT_INFO_SERIALIZER requestId:requestId to:to sessionId:sessionId expirationDeadline:expirationDeadline mode:mode sdp:data next:nil];
    
    TLSessionPendingRequest *pendingRequest = [[TLSessionPendingRequest alloc] initWithSessionId:sessionId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[reqId] = pendingRequest;
    }
    [self sendBinaryIQ:transportInfoIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send a session-ping with the session id and peer identification string.  The server will check the
/// validity of our session and return SUCCESS or EXPIRED.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionPingWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block {
    DDLogVerbose(@"%@ sessionPingWithSessionId: %@ to: %@", LOG_TAG, sessionId, to);

    int64_t requestId = [TLTwinlife newRequestId];
    NSString *fullJid = [self.twinlife getFullJid];
    TLSessionPingIQ *sessionPingIQ = [[TLSessionPingIQ alloc] initWithSerializer:IQ_SESSION_PING_SERIALIZER requestId:requestId from:fullJid to:to sessionId:sessionId];
    
    TLSessionPendingRequest *pendingRequest = [[TLSessionPendingRequest alloc] initWithSessionId:sessionId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:sessionPingIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send the session-terminate to the peer to close the P2P connection.
///
/// Note: we don't need any onComplete listener because the server never returns an error.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param reason the reason for the termination.
- (void)sessionTerminateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to reason:(TLPeerConnectionServiceTerminateReason)reason {
    DDLogVerbose(@"%@ sessionTerminateWithSessionId: %@ to: %@ reason: %d", LOG_TAG, sessionId, to, reason);

    int64_t requestId = [TLTwinlife newRequestId];
    TLSessionTerminateIQ *sessionTerminateIQ = [[TLSessionTerminateIQ alloc] initWithSerializer:IQ_SESSION_TERMINATE_SERIALIZER requestId:requestId to:to sessionId:sessionId reason:reason];
    [self sendBinaryIQ:sessionTerminateIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

/// Send the device-ringing to the peer. No TLSessionPendingRequest is added to pendingRequests as we're not expecting a response to this request.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
- (void)deviceRingingWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to {
    DDLogVerbose(@"%@ deviceRingingWithSessionId: %@ to: %@", LOG_TAG, sessionId, to);

    int64_t requestId = [TLTwinlife newRequestId];
    TLDeviceRingingIQ *deviceRingingIQ = [[TLDeviceRingingIQ alloc] initWithSerializer:IQ_DEVICE_RINGING_SERIALIZER requestId:requestId to: to sessionId:sessionId];
    
    [self sendBinaryIQ:deviceRingingIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}


#pragma mark - TLPeerCallService

/// Response received after CreateCallRoom operation.
- (void)onCreateCallRoomWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateCallRoomWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnCreateCallRoomIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    TLOnCreateCallRoomIQ *onCreateCallRoomIQ = (TLOnCreateCallRoomIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLPendingRequest *request;
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (request) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }
    if (!request) {
        return;
    }

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateCallRoomWithRequestId:callRoomId:memberId:mode:maxMemberCount:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onCreateCallRoomWithRequestId:onCreateCallRoomIQ.requestId callRoomId:onCreateCallRoomIQ.callRoomId memberId:onCreateCallRoomIQ.memberId mode:onCreateCallRoomIQ.mode maxMemberCount:onCreateCallRoomIQ.maxMemberCount];
            });
        }
    }
}

/// Response received after we have asked to join the call room.
///
/// @param iq the InviteCallRoom notification.
- (void)onJoinCallRoomWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onJoinCallRoomWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnJoinCallRoomIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    TLOnJoinCallRoomIQ *onJoinCallRoomIQ = (TLOnJoinCallRoomIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLPendingRequest *request;
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (request) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }
    if (!request) {
        return;
    }
    if (![request isKindOfClass:[TLCallRoomPendingRequest class]]) {
        return;
    }
    
    TLCallRoomPendingRequest *callRoomPendingRequest = (TLCallRoomPendingRequest *)request;

    NSMutableArray<TLPeerCallMemberInfo *> *members = [[NSMutableArray alloc] initWithCapacity:onJoinCallRoomIQ.members != nil ? onJoinCallRoomIQ.members.count : 0];
    if (onJoinCallRoomIQ.members) {
        for (TLMemberSessionInfo *member in onJoinCallRoomIQ.members) {
            if (member.sessionId) {
                [members addObject:[[TLPeerCallMemberInfo alloc] initWithMemberId:member.memberId p2pSessionId:member.sessionId]];
            } else {
                [members addObject:[[TLPeerCallMemberInfo alloc] initWithMemberId:member.memberId]];
            }
        }
    }
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onJoinCallRoomWithRequestId:callRoomId:memberId:members:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onJoinCallRoomWithRequestId:onJoinCallRoomIQ.requestId callRoomId:callRoomPendingRequest.callRoomId memberId:onJoinCallRoomIQ.memberId members:members];
            });
        }
    }
}

/// Response received after LeaveCallRoom operation.
///
/// @param iq the OnLeaveCallRoomIQ response.
- (void)onLeaveCallRoomWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onLeaveCallRoomWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLPendingRequest *request;
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (request) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }
    if (!request) {
        return;
    }
    if (![request isKindOfClass:[TLCallRoomPendingRequest class]]) {
        return;
    }
    
    TLCallRoomPendingRequest *callRoomPendingRequest = (TLCallRoomPendingRequest *)request;

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onLeaveCallRoomWithRequestId:callRoomId:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onLeaveCallRoomWithRequestId:iq.requestId callRoomId:callRoomPendingRequest.callRoomId];
            });
        }
    }
}

/// Notification IQ received when we are invited to join a call room.
///
/// @param iq the InviteCallRoom notification.
- (void)onInviteCallRoomWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onInviteCallRoomWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLInviteCallRoomIQ class]]) {
        return;
    }
    
    TLInviteCallRoomIQ *inviteCallRoomIQ = (TLInviteCallRoomIQ *)iq;

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onInviteCallRoomWithCallRoomId:twincodeInboundId:p2pSessionId:mode:maxMemberCount:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onInviteCallRoomWithCallRoomId:inviteCallRoomIQ.callRoomId twincodeInboundId:inviteCallRoomIQ.twincodeId p2pSessionId:inviteCallRoomIQ.p2pSessionId mode:inviteCallRoomIQ.mode maxMemberCount:inviteCallRoomIQ.maxMemberCount];
            });
        }
    }
}

/// Notification IQ received when we are invited to join a call room.
///
/// @param iq the InviteCallRoom notification.
- (void)onMemberNotificationWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onMemberNotificationWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLMemberNotificationIQ class]]) {
        return;
    }
    
    TLMemberNotificationIQ *memberNotificationIQ = (TLMemberNotificationIQ *)iq;

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onMemberJoinCallRoomWithCallRoomId:memberId:p2pSessionId:status:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLPeerCallServiceDelegate>)delegate onMemberJoinCallRoomWithCallRoomId:memberNotificationIQ.callRoomId memberId:memberNotificationIQ.memberId p2pSessionId:memberNotificationIQ.p2pSessionId status:memberNotificationIQ.status];
            });
        }
    }
}

/// Handle the ack packet sent back from the server after a session-initiate, session-accept, session-update,.
///
/// @param iq the ack packet.
- (void)onAckPacketWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAckPacketWithIQ: %@", LOG_TAG, iq);
    
    [self receivedBinaryIQ:iq];

    NSNumber *requestId = [NSNumber numberWithLongLong:iq.requestId];
    TLPendingRequest *request;
    @synchronized (self) {
        request = self.pendingRequests[requestId];
        if (request) {
            [self.pendingRequests removeObjectForKey:requestId];
        }
    }
    if (!request) {
        return;
    }
    if (!([request isKindOfClass:[TLSessionPendingRequest class]])) {
        return;
    }
    if (![iq isKindOfClass:[TLBinaryErrorPacketIQ class]]) {
        return;
    }

    TLSessionPendingRequest *sessionPendingRequest = (TLSessionPendingRequest *)request;
    TLBinaryErrorPacketIQ *errorIQ = (TLBinaryErrorPacketIQ *)iq;
    sessionPendingRequest.consumer(errorIQ.errorCode, requestId);
}

/// Message received when a peer wants to setup a new P2P session.
///
/// @param iq SessionInitiateIQ request.
- (void)onSessionInitiateWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSessionInitiateWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSessionInitiateIQ class]]) {
        return;
    }
    
    TLSessionInitiateIQ *sessionInitiateIQ = (TLSessionInitiateIQ *)iq;
    TLVersion *version = [[TLVersion alloc] initWithMajor:sessionInitiateIQ.majorVersion minor:sessionInitiateIQ.minorVersion patch:0];
    TLOffer *offer = [TLPeerCallService createOfferWithOffer:sessionInitiateIQ.offer version:version];
    TLOfferToReceive *offerToReceive = [TLPeerCallService createOfferToReceiveWithOffer:sessionInitiateIQ.offerToReceive];
    TLSdp *sdp = [sessionInitiateIQ makeSdp];
    
    TLBaseServiceErrorCode result = [self.peerSignalingDelegate onSessionInitiateWithSessionId:sessionInitiateIQ.sessionId from:sessionInitiateIQ.from to:sessionInitiateIQ.to sdp:sdp offer:offer offerToReceive:offerToReceive maxReceivedFrameSize:sessionInitiateIQ.frameSize maxReceivedFrameRate:sessionInitiateIQ.frameRate];

    // Don't send a response if we get the Offline error: it means we are shutting down and can't handle
    // a new P2P incoming session.
    if (result != TLBaseServiceErrorCodeTwinlifeOffline) {
        
        TLBinaryErrorPacketIQ *responseIQ = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:IQ_ON_SESSION_INITIATE_SERIALIZER requestId:sessionInitiateIQ.requestId errorCode:result];
        
        [self sendResponseIQ:responseIQ factory:self.serializerFactory];
    }
}

/// Message received when a peer wants to setup a new P2P session.
///
/// @param iq SessionInitiateIQ request.
- (void)onSessionAcceptWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSessionAcceptWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSessionAcceptIQ class]]) {
        return;
    }
    
    TLSessionAcceptIQ *sessionAcceptIQ = (TLSessionAcceptIQ *)iq;
    TLVersion *version = [[TLVersion alloc] initWithMajor:sessionAcceptIQ.majorVersion minor:sessionAcceptIQ.minorVersion patch:0];
    TLOffer *offer = [TLPeerCallService createOfferWithOffer:sessionAcceptIQ.offer version:version];
    TLOfferToReceive *offerToReceive = [TLPeerCallService createOfferToReceiveWithOffer:sessionAcceptIQ.offerToReceive];
    TLSdp *sdp = [sessionAcceptIQ makeSdp];
    
    TLBaseServiceErrorCode result = [self.peerSignalingDelegate onSessionAcceptWithSessionId:sessionAcceptIQ.sessionId sdp:sdp offer:offer offerToReceive:offerToReceive maxReceivedFrameSize:sessionAcceptIQ.frameSize maxReceivedFrameRate:sessionAcceptIQ.frameRate];

    TLBinaryErrorPacketIQ *responseIQ = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:IQ_ON_SESSION_ACCEPT_SERIALIZER requestId:sessionAcceptIQ.requestId errorCode:result];

    [self sendResponseIQ:responseIQ factory:self.serializerFactory];
}

/// Message received when a peer wants to re-negotiate the SDP in an existing P2P session.
///
/// @param iq SessionUpdateIQ request.
- (void)onSessionUpdateWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSessionUpdateWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSessionUpdateIQ class]]) {
        return;
    }
    
    TLSessionUpdateIQ *sessionUpdateIQ = (TLSessionUpdateIQ *)iq;
    RTCSdpType type = (sessionUpdateIQ.updateType & OFFER_ANSWER) ? RTCSdpTypeAnswer : RTCSdpTypeOffer;
    TLSdp *sdp = [sessionUpdateIQ makeSdp];
    
    TLBaseServiceErrorCode result = [self.peerSignalingDelegate onSessionUpdateWithSessionId:sessionUpdateIQ.sessionId updateType:type sdp:sdp];

    TLBinaryErrorPacketIQ *responseIQ = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:IQ_ON_SESSION_UPDATE_SERIALIZER requestId:sessionUpdateIQ.requestId errorCode:result];

    [self sendResponseIQ:responseIQ factory:self.serializerFactory];
}

/// Message received to give the candidates for the P2P session.
///
/// @param iq TransportInfoIQ request.
- (void)onTransportInfoWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onTransportInfoWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLTransportInfoIQ class]]) {
        return;
    }
    
    TLTransportInfoIQ *transportInfoIQ = (TLTransportInfoIQ *)iq;
    TLBaseServiceErrorCode result;
    do {
        TLSdp *sdp = [transportInfoIQ makeSdp];
        result = [self.peerSignalingDelegate onTransportInfoWithSessionId:transportInfoIQ.sessionId sdp:sdp];
        transportInfoIQ = transportInfoIQ.next;
    } while (result == TLBaseServiceErrorCodeSuccess && transportInfoIQ);

    TLBinaryErrorPacketIQ *responseIQ = [[TLBinaryErrorPacketIQ alloc] initWithSerializer:IQ_ON_TRANSPORT_INFO_SERIALIZER requestId:transportInfoIQ.requestId errorCode:result];

    [self sendResponseIQ:responseIQ factory:self.serializerFactory];
}

/// Message received when a peer terminates the P2P session.
///
/// @param iq SessionTerminateIQ request.
- (void)onSessionTerminateWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onSessionTerminateWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLSessionTerminateIQ class]]) {
        return;
    }
    
    TLSessionTerminateIQ *sessionTerminateIQ = (TLSessionTerminateIQ *)iq;
    [self.peerSignalingDelegate onSessionTerminateWithSessionId:sessionTerminateIQ.sessionId reason:sessionTerminateIQ.reason];

    TLBinaryPacketIQ *responseIQ = [[TLBinaryPacketIQ alloc] initWithSerializer:IQ_ON_SESSION_TERMINATE_SERIALIZER requestId:sessionTerminateIQ.requestId];

    [self sendResponseIQ:responseIQ factory:self.serializerFactory];
}

/// Message received when the peer's device is ringing.
///
/// @param iq DeviceRingingIQ request.

- (void)onDeviceRingingWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeviceRingingWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLDeviceRingingIQ class]]) {
        return;
    }
    
    TLDeviceRingingIQ *deviceRingingIQ = (TLDeviceRingingIQ *)iq;
    [self.peerSignalingDelegate onDeviceRingingWithSessionId:deviceRingingIQ.sessionId];
}


- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);

    int64_t requestId = errorPacketIQ.requestId;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLPendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

}

@end
